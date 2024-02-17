#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch] $OnlyMonitor = $false
)
$PSDefaultParameterValues = @{"*:Verbose" = ($VerbosePreference -eq 'Continue') }
$ErrorActionPreference = 'Stop'

$app_version = "Fibocom Connect FM350 v2024.02.1"

Clear-Host

$bufferSize = $Host.UI.RawUI.BufferSize
$bufferSize.Height = 1000
$Host.UI.RawUI.BufferSize = $bufferSize

$Host.UI.RawUI.WindowTitle = $app_version
if ($OnlyMonitor) {
    $Host.UI.RawUI.WindowTitle += " (monitor)"
}

Write-Host "=== $app_version ==="

# COM port display name search string. Supports wildcard. Could be "*COM7*" if 'MD AT' port does not exists on your machine
$COM_NAME = "*MD AT*"

$APN = "internet"
#$APN_USER = ""
#$APN_PASS = ""

# Override dns settings. Example: @('8.8.8.8', '1.1.1.1')
$DNS_OVERRIDE = @()


### Ublock files
Get-ChildItem -Recurse -Path .\ -Include *.ps1, *.psm1, *.psd1, *.dll | Unblock-File

### Import modules
if (-Not(Get-Command | Where-Object { $_.Name -like 'Start-ThreadJob' })) {
    Import-Module -Global ./modules/ThreadJob/ThreadJob.psd1
}
Import-Module ./modules/common.psm1
Import-Module ./modules/serial-port.psm1
Import-Module ./modules/converters.psm1
Import-Module ./modules/network.psm1

try {
    while ($true) {
        Clear-Host

        Write-Host "=== $app_version ==="

        $modem_port_result = Wait-Action -Message 'Search modem control port' -Action {
            while ($true) {
                $port_result = Get-SerialPort -FriendlyName $COM_NAME
                if ($port_result) {
                    Start-Sleep -Seconds 2 | Out-Null
                    return $port_result
                }
                Start-Sleep -Seconds 5 | Out-Null
            }
        }

        $modem_port = $modem_port_result[0]
        $modem_containerId = $modem_port_result[1]

        Write-Host "Found modem control port: $modem_port"

        if ($modem) {
            $modem.Dispose()
            $modem = $null
        }

        $modem = Wait-Action -Message 'Open modem control port' -Action {
            $local_modem = New-SerialPort -Name $modem_port
            Open-SerialPort -Port $local_modem
            return $local_modem
        }

        Send-ATCommand -Port $modem -Command "ATE1" | Out-Null
        Send-ATCommand -Port $modem -Command "AT+CMEE=2" | Out-Null

        ### Get modem information
        Write-Host
        Write-Host "=== Modem information ==="

        $response = Send-ATCommand -Port $modem -Command "AT+CGMI?; +FMM?; +GTPKGVER?; +CFSN?; +CGSN?"

        $manufacturer = $response | Awk -Split '[:,]' -Filter '\+CGMI:' -Action { $args[1] -replace '"|^\s', '' }
        $model = $response | Awk -Split '[:,]' -Filter '\+FMM:' -Action { $args[1] -replace '"|^\s', '' }
        $firmwareVer = $response | Awk -Filter '\+GTPKGVER:' -Action { $args[1] -replace '"', '' }
        $serialNumber = $response | Awk -Filter '\+CFSN:' -Action { $args[1] -replace '"', '' }
        $imei = $response | Awk -Filter '\+CGSN:' -Action { $args[1] -replace '"', '' }

        Write-Host "Manufacturer: $manufacturer"
        Write-Host "Model: $model"
        Write-Host "Firmware: $firmwareVer"
        Write-Host "Serial: $serialNumber"
        Write-Host "IMEI: $imei"

        ### Check SIM Card
        $response = Send-ATCommand -Port $modem -Command "AT+CPIN?"
        if (-Not($response -match '\+CPIN: READY')) {
            Write-Error2 "Check SIM card."
            Write-Error2 $response
            exit 1
        }

        ### Get SIM information
        $response = Send-ATCommand -Port $modem -Command "AT+CIMI?; +CCID?"

        $imsi = $response | Awk -Filter '\+CIMI:' -Action { $args[1] -replace '"', '' }
        $ccid = $response | Awk -Filter '\+CCID:' -Action { $args[1] -replace '"', '' }

        Write-Host "IMSI: $imsi"
        Write-Host "ICCID: $ccid"

        if (-Not($OnlyMonitor)) {
            ### Connect
            Write-Host
            Wait-Action -Message "Initialize connection" -Action {
                $response = ''
                $response = Send-ATCommand -Port $modem -Command "AT+CFUN=1"
                $response = Send-ATCommand -Port $modem -Command "AT+CGPIAF=1,0,0,0"
                $response = Send-ATCommand -Port $modem -Command "AT+CREG=0"
                $response = Send-ATCommand -Port $modem -Command "AT+CEREG=0"
                $response = Send-ATCommand -Port $modem -Command "AT+CGATT=0"
                $response = Send-ATCommand -Port $modem -Command "AT+COPS=2"

                $response = Send-ATCommand -Port $modem -Command "AT+CGDCONT=0,`"IP`""
                $response = Send-ATCommand -Port $modem -Command "AT+CGDCONT=0"
                $response = Send-ATCommand -Port $modem -Command "AT+CGDCONT=1,`"IPV4V6`",`"$APN`""

                $response = Send-ATCommand -Port $modem -Command "AT+COPS=0,0"
                if (Test-AtResponseError $response) {
                    Write-Error2 $response
                    exit 1
                }

                $response = Send-ATCommand -Port $modem -Command "AT+CGACT=1,1"
                $response = Send-ATCommand -Port $modem -Command "AT+CGATT=1"
            }

            Wait-Action -Message "Establish connection" -Action {
                while ($true) {
                    $response = Send-ATCommand -Port $modem -Command "AT+CGATT?; +CSQ?"
                    $cgatt = $response | Awk -Split '[:,]' -Filter '\+CGATT:' -Action { [int]$args[1] }
                    $csq = $response | Awk -Split '[:,]' -Filter '\+CSQ:' -Action { [int]$args[1] }
                    if ($cgatt -eq 1 -and $csq -ne 99) {
                        break
                    }
                    Start-Sleep -Seconds 2
                }
            }
        }

        Write-Host
        Write-Host "=== Connection information ==="

        $ip_addr = "--"
        $ip_mask = "--"
        $ip_gw = "--"
        [string[]]$ip_dns = @()

        $response = Send-ATCommand -Port $modem -Command "AT+CGPADDR=1; +GTDNS=1"

        if (-Not (Test-AtResponseError $response)) {
            $ip_addr = $response | Awk -Split '[:,]' -Filter '\+CGPADDR:' -Action { $args[2] -replace '"', '' } | Select-Object -First 1
            if (-Not($ip_addr)) {
                Write-Error2 "Could not get ip address."
                Write-Error2 $response
                exit 1
            }
            $ip_gw = (($ip_addr -split '\.' | Select-Object -First 3) + '1') -join '.'
            $ip_mask = '255.255.255.0'
            $ip_dns += $response | Awk -Split '[:,]' -Filter '\+GTDNS:' -Action { $args[2] -replace '"', '' } | Select-Object -First 1
            $ip_dns += $response | Awk -Split '[:,]' -Filter '\+GTDNS:' -Action { $args[3] -replace '"', '' } | Select-Object -First 1
            [string[]]$ip_dns = $ip_dns | Where-Object { -Not([string]::IsNullOrWhiteSpace($_)) }
        }
        elseif (-Not($OnlyMonitor)) {
            Write-Error2 "Could not get ip address."
            Write-Error2 $response
            exit 1
        }

        Write-Host "IP: $ip_addr"
        Write-Host "MASK: $ip_mask"
        Write-Host "GW: $ip_gw"

        $DNS_OVERRIDE = $DNS_OVERRIDE | Where-Object { -Not([string]::IsNullOrWhiteSpace($_)) }
        if ($DNS_OVERRIDE.Length -gt 0) {
            $ip_dns = $DNS_OVERRIDE
        }

        for (($i = 0); $i -lt $ip_dns.Length; $i++) {
            Write-Host "DNS$($i+1): $($ip_dns[$i])"
        }

        if (-Not($OnlyMonitor)) {
            Wait-Action -ErrorAction SilentlyContinue -Message "Setup network" -Action {
                $interfaceIndex = Get-NetworkInterface -ContainerId $modem_containerId
                if (-Not($interfaceIndex)) {
                    Write-Error2 "Could not find network interface"
                    exit 1
                }

                Initialize-Network -InterfaceIndex $interfaceIndex -IpAddress $ip_addr -IpMask $ip_mask -IpGateway $ip_gw -IpDns $ip_dns
            }
        }


        ## Watchdog

        $watchdogEventSource = "WatchdogEvent"
        Start-SerialPortMonitoring -WatchdogSourceIdentifier $watchdogEventSource -FriendlyName $COM_NAME
        Start-NetworkMonitoring -WatchdogSourceIdentifier $watchdogEventSource -ContainerId $modem_containerId

        ### Monitoring
        Write-Host
        Write-Host "=== Status ==="
        $cursorSize = $Host.UI.RawUI.CursorSize; $Host.UI.RawUI.CursorSize = 0
        try {
            $statusCursorPosition = $Host.UI.RawUI.CursorPosition

            while ($true) {
                if ((Get-Event -SourceIdentifier $watchdogEventSource -ErrorAction SilentlyContinue)) {
                    break
                }

                $response = ''

                $response += Send-ATCommand -Port $modem -Command "AT+COPS?"
                $response += Send-ATCommand -Port $modem -Command "AT+CSQ?"
                $response += Send-ATCommand -Port $modem -Command "AT+CESQ?"
                $response += Send-ATCommand -Port $modem -Command "AT+CGREG?"
                $response += Send-ATCommand -Port $modem -Command "AT+CEREG?"
                $response += Send-ATCommand -Port $modem -Command "AT+GTSENRDTEMP=1"
                $response += Send-ATCommand -Port $modem -Command "AT+GTCCINFO?"
                $response += Send-ATCommand -Port $modem -Command "AT+GTCAINFO?"
                $response += Send-ATCommand -Port $modem -Command "AT+RSRP?"
                $response += Send-ATCommand -Port $modem -Command "AT+RSRQ?"

                if ([string]::IsNullOrEmpty($response)) {
                    continue
                }

                [nullable[int]]$tech = $response | Awk -Split '(?<=\+COPS):|,' -Filter '\+COPS:' -Action { $args[4] }
                $mode = switch ($tech) {
                    0 { 'EDGE' }
                    2 { 'UMTS' }
                    3 { 'LTE' }
                    4 { 'HSDPA' }
                    5 { 'HSUPA' }
                    6 { 'HSPA' }
                    7 { 'LTE' }
                    default { $null }
                }

                $oper = $response | Awk -Split '(?<=\+COPS):|,' -Filter '\+COPS:' -Action { $args[3] -replace '"', '' }

                [nullable[int]]$temp = $response | Awk -Split '[:,]' -Filter '\+GTSENRDTEMP:' -Action { $args[2] }
                if ($temp -gt 0) { $temp = $temp / 1000 }

                $csq = $response | Awk -Split '[:,]' -Filter '\+CSQ:' -Action { [int]$args[1] }
                $csq_perc = 0
                if ($csq -ge 0 -and $csq -le 31) {
                    $csq_perc = $csq * 100 / 31
                }
                # $cqs_rssi = 2 * $csq - 113

                # [nullable[int]]$u_dluarfnc = $response | Awk -Split '[:,]' -Filter '\+XMCI: 2' -Action { $args[7] -replace '"', '' }
                # [nullable[double]]$u_rssi = $response | Awk -Split '[:,]' -Filter '\+XMCI: 2' -Action { [int]$args[10] - 111 }
                # [nullable[double]]$u_rscp = $response | Awk -Split '[:,]' -Filter '\+XMCI: 2' -Action { [int]$args[11] - 121 }
                # [nullable[double]]$u_ecno = $response | Awk -Split '[:,]' -Filter '\+XMCI: 2' -Action { ([int]$args[12] / 2) - 24 }

                # [nullable[int]]$dluarfnc = $response | Awk -Split '[:,]' -Filter '\+XMCI: 4' -Action { $args[7] -replace '"', '' }
                # [nullable[double]]$rsrp = $response | Awk -Split '[:,]' -Filter '\+XMCI: 4' -Action { ([int]$args[10]) - 141 }
                # [nullable[double]]$rsrq = $response | Awk -Split '[:,]' -Filter '\+XMCI: 4' -Action { ([int]$args[11]) / 2 - 20 }
                # [nullable[double]]$sinr = $response | Awk -Split '[:,]' -Filter '\+XMCI: 4' -Action { ([int]$args[12]) / 2 }
                # [nullable[int]]$ta = $response | Awk -Split '[:,]' -Filter '\+XMCI: 4' -Action { $args[13] -replace '"', '' }
                # $distance = Invoke-NullCoalescing { [Math]::Round(($ta * 78.125) / 1000, 3) } { $null }

                # [nullable[int]]$bw = $response | Awk -Split '[:,]' -Filter '\+XLEC:' -Action { [int]$args[3] }

                # $rssi = Convert-RsrpToRssi $rsrp $bw


                # [int[]]$ci_x = $response | Awk -Split '[:,]' -Filter '\+XMCI: [45]' -Action { [int]($args[5] -replace '"', '') }
                # [int[]]$pci_x = $response | Awk -Split '[:,]' -Filter '\+XMCI: [45]' -Action { [int]($args[6] -replace '"', '') }
                # [int[]]$dluarfnc_x = $response | Awk -Split '[:,]' -Filter '\+XMCI: [45]' -Action { [int]($args[7] -replace '"', '') }
                # [string[]]$band_x = $dluarfnc_x | Get-BandLte
                # [int[]]$rsrp_x = $response | Awk -Split '[:,]' -Filter '\+XMCI: [45]' -Action { ([int]$args[10]) - 141 }
                # [int[]]$rsrq_x = $response | Awk -Split '[:,]' -Filter '\+XMCI: [45]' -Action { ([int]$args[11]) / 2 - 20 }

                # $band = '--'
                # $ca_match = [regex]::Match($response, "\+XLEC: (?:\d+),(?<no_of_cells>\d+),(?:(?<bw>\d+),*)+(?:BAND_LTE_(?:(?<band>\d+),*)+)?")
                # if ($ca_match.Success) {
                #     $ca_number = $ca_match.Groups['no_of_cells'].Value

                #     [int[]]$ca_bw_x = $ca_match.Groups['bw'].Captures | ForEach-Object { [int]$_.Value }
                #     [string[]]$ca_band_x = $ca_match.Groups['band'].Captures | Where-Object { $_.Value -gt 0 } | ForEach-Object { "B$_" }

                #     if ($ca_band_x.Length -ne $ca_number) {
                #         $ca_band_x = $band_x
                #     }

                #     $band = ''
                #     for (($i = 0); $i -lt $ca_number; $i++) {
                #         $band += "{0}@{1}MHz " -f $ca_band_x[$i], (Get-BandwidthFrequency $ca_bw_x[$i])
                #     }
                # }
                # elseif ($null -ne $dluarfnc) {
                #     $band = "{0}@{1}MHz" -f (Get-BandLte $dluarfnc), (Get-BandwidthFrequency $bw)
                # }

                ### Display
                $Host.UI.RawUI.CursorPosition = $statusCursorPosition

                $lineWidth = $Host.UI.RawUI.BufferSize.Width
                $titleWidth = 17

                if ($null -ne $temp) {
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0} $([char]0xB0)C" -f "Temp:", $temp))
                }
                else {
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4}" -f "Temp:", '--'))
                }

                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1} ({2})" -f "Operator:", (Invoke-NullCoalescing $oper '----'), (Invoke-NullCoalescing $mode '--')))

                # if ($null -ne $mode) {
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1}km" -f "Distance:", (Invoke-NullCoalescing $distance '--')))
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}%   {2}" -f "Signal:", $csq_perc, (Get-Bars -Value $csq_perc -Min 0 -Max 100)))
                # }
                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}%   {2}" -f "Signal:", $csq_perc, (Get-Bars -Value $csq_perc -Min 0 -Max 100)))

                # if ($mode -eq 'UMTS') {
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dBm {2}" -f "RSSI:", $u_rssi, (Get-Bars -Value $u_rssi -Min -120 -Max -25)))
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dBm {2}" -f "RSCP:", $u_rscp, (Get-Bars -Value $u_rscp -Min -120 -Max -25)))
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dB  {2}" -f "ECNO:", $u_ecno, (Get-Bars -Value $u_ecno -Min -24 -Max 0)))
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1}" -f "UARFCN:", $u_dluarfnc))
                # }
                # elseif ($mode -eq 'LTE') {

                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dBm {2}" -f "RSSI:", $rssi, (Get-Bars -Value $rssi -Min -110 -Max -25)))
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dB  {2}" -f "SINR:", $sinr, (Get-Bars -Value $sinr -Min -10 -Max 30)))
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dBm {2}" -f "RSRP:", $rsrp, (Get-Bars -Value $rsrp -Min -120 -Max -50)))
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dB  {2}" -f "RSRQ:", $rsrq, (Get-Bars -Value $rsrq -Min -25 -Max -1)))

                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1}" -f "Band:", $band))
                #     Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1}" -f "EARFCN:", (Invoke-NullCoalescing $dluarfnc '--')))

                #     $carriers_count = $pci_x.Length
                #     for (($i = 0); $i -lt $carriers_count; $i++) {
                #         Write-Host -NoNewline ("===Carrier {0,2}: " -f ($i + 1))
                #         Write-Host -NoNewline ("{0} {1,9} " -f "CI:", $ci_x[$i])
                #         Write-Host -NoNewline ("{0} {1,5} " -f "PCI:", $pci_x[$i])
                #         Write-Host -NoNewline ("{0} {1,3} ({2,5}) " -f "Band (EARFCN):", $band_x[$i], $dluarfnc_x[$i])
                #         Write-Host -NoNewline ("{0} {1,4:f0}dBm {2} " -f "RSRP:", $rsrp_x[$i], (Get-Bars -Value $rsrp_x[$i] -Min -120 -Max -50))
                #         Write-Host -NoNewline ("{0} {1,4:f0}dB  {2} " -f "RSRQ:", $rsrq_x[$i], (Get-Bars -Value $rsrq_x[$i] -Min -25 -Max -1))
                #         Write-Host
                #     }
                # }

                ### Clear
                $lastCusrsorPosition = $Host.UI.RawUI.CursorPosition
                $cleanBuffer = $Host.UI.RawUI.NewBufferCellArray(
                    @{ Width = $Host.UI.RawUI.BufferSize.Width; Height = 200 },
                    @{ Character = ' '; ForegroundColor = $Host.UI.RawUI.ForegroundColor; BackgroundColor = $Host.UI.RawUI.BackgroundColor } )
                $Host.UI.RawUI.SetBufferContents($lastCusrsorPosition, $cleanBuffer)

                Start-Sleep -Seconds 2
            }
        }
        catch {
            Write-Error2 $_
            Start-Sleep -Seconds 5
        }
        finally {
            $Host.UI.RawUI.CursorSize = $cursorSize
        }

        Stop-NetworkMonitoring
        Stop-SerialPortMonitoring
        Get-Event -SourceIdentifier $watchdogEventSource -ErrorAction SilentlyContinue | Remove-Event
        Close-SerialPort -Port $modem
    }
}
finally {
    Stop-NetworkMonitoring
    Stop-SerialPortMonitoring
    Close-SerialPort -Port $modem
}

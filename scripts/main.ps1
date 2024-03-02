#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch] $OnlyMonitor = $false
)
$PSDefaultParameterValues = @{"*:Verbose" = ($VerbosePreference -eq 'Continue') }
$ErrorActionPreference = 'Stop'

$app_version = "Fibocom Connect FM350 v2024.02.2"

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

# Set your APN
$APN = "internet"

# Override dns settings. Example: @('8.8.8.8', '1.1.1.1')
$DNS_OVERRIDE = @()


### Ublock files
Get-ChildItem -Recurse -Path .\ -Include *.ps1, *.psm1, *.psd1, *.dll | Unblock-File

### Import modules
if (-Not(Get-Command | Where-Object { $_.Name -like 'Start-ThreadJob' })) {
    Import-Module -Global ./modules/ThreadJob/ThreadJob.psd1
}
Import-Module ./modules/common.psm1
Import-Module ./modules/converters.psm1
Import-Module ./modules/serial-port.psm1
Import-Module ./modules/network.psm1

$defaultCursorSize = $Host.UI.RawUI.CursorSize;

$modem = $null

### Hide cursor
$Host.UI.RawUI.CursorSize = 0

while ($true) {
    try {
        Clear-Host

        $scriptStartedAt = Get-Date

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
        $firmwareVer = $response | Awk -Split '[:,]' -Filter '\+GTPKGVER:' -Action { $args[1] -replace '"|^\s', '' }
        $serialNumber = $response | Awk -Split '[:,]' -Filter '\+CFSN:' -Action { $args[1] -replace '"|^\s', '' }
        $imei = $response | Awk -Split '[:,]' -Filter '\+CGSN:' -Action { $args[1] -replace '"|^\s', '' }

        Write-Host "Manufacturer: $manufacturer"
        Write-Host "Model: $model"
        Write-Host "Firmware: $firmwareVer"
        Write-Host "Serial: $serialNumber"
        Write-Host "IMEI: $imei"

        if (-Not($OnlyMonitor)) {
            ### Check SIM Card
            $response = Send-ATCommand -Port $modem -Command "AT+CPIN?"
            if (-Not($response -match '\+CPIN: READY')) {
                Write-Error2 "Check SIM card."
                Write-Error2 $response
                exit 1
            }
        }

        ### Get SIM information
        $response = ''
        $response += Send-ATCommand -Port $modem -Command "AT+GTDUALSIM?"
        $response += Send-ATCommand -Port $modem -Command "AT+SIMTYPE?"
        $response += Send-ATCommand -Port $modem -Command "AT+CIMI?; +CCID?"

        $dual_sim = $response | Awk -Split '[:,]' -Filter '\+GTDUALSIM\s?:' -Action {
            [pscustomobject]@{ sim_app = [int]$args[1]; sub_app = ($args[2] -replace '"|^\s', ''); sys_mode = (($args[3] -replace '"|^\s', '') | Get-SimSysMode); }
        }
        $sim_type = $response | Awk -Split '[:,]' -Filter '\+SIMTYPE:' -Action { [int]$args[1] | Get-SimType }
        $imsi = $response | Awk -Split '[:,]' -Filter '\+CIMI:' -Action { $args[1] -replace '"|^\s', '' }
        $ccid = $response | Awk -Split '[:,]' -Filter '\+CCID:' -Action { $args[1] -replace '"|^\s', '' }

        if ($dual_sim) {
            $dual_sim | ForEach-Object {
                $sim = $_
                Write-Host "SIM $($sim.sim_app): $($sim.sub_app) $($sim.sys_mode)"
            }
        }
        else {
            Write-Host "SIM: Unknown"
        }
        Write-Host "SIM TYPE: $sim_type"
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
        if (-Not($OnlyMonitor)) {
            Start-NetworkMonitoring -WatchdogSourceIdentifier $watchdogEventSource -ContainerId $modem_containerId
        }

        ### Monitoring
        Write-Host
        Write-Host "=== Status ==="

        $Host.UI.RawUI.CursorSize = 0
        $statusCursorPosition = $Host.UI.RawUI.CursorPosition

        #### Min Max values
        $rscp_min = Get-UmtsRscp 0
        $rscp_max = Get-UmtsRscp 96
        $ecno_min = Get-UmtsEcno 0
        $ecno_max = Get-UmtsEcno 49

        $lte_sinr_min = Get-LteSinr -100
        $lte_sinr_max = Get-LteSinr 100
        $lte_rsrp_min = Get-LteRsrp 0
        $lte_rsrp_max = Get-LteRsrp 97
        $lte_rsrq_min = Get-LteRsrq 0
        $lte_rsrq_max = Get-LteRsrq 34

        $nr_sinr_min = Get-NrSinr 0
        $nr_sinr_max = Get-NrSinr 127
        $nr_rsrp_min = Get-NrRsrp 0
        $nr_rsrp_max = Get-NrRsrp 126
        $nr_rsrq_min = Get-NrRsrq 0
        $nr_rsrq_max = Get-NrRsrq 126


        while ($true) {
            if ((Get-Event -SourceIdentifier $watchdogEventSource -ErrorAction SilentlyContinue)) {
                break
            }

            $response = ''

            $response += Send-ATCommand -Port $modem -Command "AT+COPS?"
            $response += Send-ATCommand -Port $modem -Command "AT+CSQ?"
            $response += Send-ATCommand -Port $modem -Command "AT+GTSENRDTEMP=1"
            $response += Send-ATCommand -Port $modem -Command "AT+GTCCINFO?"
            $response += Send-ATCommand -Port $modem -Command "AT+GTCAINFO?"

            if ([string]::IsNullOrEmpty($response)) {
                continue
            }

            [nullable[int]]$tech = $response | Awk -Split '(?<=\+COPS):|,' -Filter '\+COPS:' -Action { $args[4] }
            $mode = switch ($tech) {
                0 { 'EDGE' }
                1 { 'EDGE' }
                2 { 'UMTS' }
                3 { 'EDGE' }
                4 { 'HSDPA' }
                5 { 'HSUPA' }
                6 { 'UMTS' }
                7 { 'LTE' }
                8 { 'CDMA' }
                9 { 'CDMA+EVDO' }
                10 { 'EVDO' }
                11 { 'eMTC' }
                12 { 'NB-IoT' }
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

            $cc_cells = @()
            $cc_match = [regex]::Match($response, "\+GTCCINFO:\s*(?:(?<cell>[12],.+)\s*){0,}")
            if ($cc_match.Success) {
                $cc_cells += $cc_match.Groups['cell'].Captures | ForEach-Object {
                    $cell = @{}
                    $cell_value = $_.Value
                    $cell_value_arr = $cell_value -split ','

                    $cell.is_service_cell = $cell_value_arr[0] -eq 1
                    $cell.rat = [int]$cell_value_arr[1] | Get-Rat
                    $cell.tac_lac = [int]"0x$($cell_value_arr[4])" | Get-TacOrLac
                    $cell.cell_id = [int]"0x$($cell_value_arr[5])" | Get-CellId
                    $cell.arfcn = [int]$cell_value_arr[6]

                    if ($cell.rat -eq 'UMTS') {
                        $cell.p_cell_id = [int]$cell_value_arr[7] | Get-PCellId

                        if ($cell.is_service_cell) {
                            $cell.band = [int]$cell_value_arr[8] | Get-UmtsBand
                            $cell.ecno = [int]$cell_value_arr[9] | Get-UmtsEcno
                            $cell.rscp = [int]$cell_value_arr[10] | Get-UmtsRscp
                        }
                        else {
                            $cell.ecno = [int]$cell_value_arr[11] | Get-UmtsEcno
                            $cell.rscp = [int]$cell_value_arr[14] | Get-UmtsRscp
                        }
                    }
                    elseif ($cell.rat -eq 'LTE') {
                        $cell.p_cell_id = [int]$cell_value_arr[7] | Get-PCellId

                        if ($cell.is_service_cell) {
                            $cell.band = $cell.arfcn | Convert-ToLteOrNrBand
                            $cell.bandwidth = [int]$cell_value_arr[9] | Get-LteBandwidthFrequency
                            $cell.sinr = [int]$cell_value_arr[10] | Get-LteSinr
                            $cell.rsrp = [int]$cell_value_arr[12] | Get-LteRsrp
                            $cell.rsrq = [int]$cell_value_arr[13] | Get-LteRsrq
                        }
                        else {
                            $cell.band = $cell.arfcn | Convert-ToLteOrNrBand
                            $cell.bandwidth = [int]$cell_value_arr[8] | Get-LteBandwidthFrequency
                            $cell.rsrp = [int]$cell_value_arr[10] | Get-LteRsrp
                            $cell.rsrq = [int]$cell_value_arr[11] | Get-LteRsrq
                        }
                    }
                    elseif ($cell.rat -eq 'NR') {
                        $cell.p_cell_id = [int]$cell_value_arr[7] | Get-PCellId
                        if ($cell.is_service_cell) {
                            $cell.band = $cell.arfcn | Convert-ToLteOrNrBand
                            $cell.bandwidth = [int]$cell_value_arr[9] | Get-NrBandwidthFrequency
                            $cell.sinr = [int]$cell_value_arr[10] | Get-NrSinr
                            $cell.rsrp = [int]$cell_value_arr[12] | Get-NrRsrp
                            $cell.rsrq = [int]$cell_value_arr[13] | Get-NrRsrq
                        }
                        else {
                            $cell.band = $cell.arfcn | Convert-ToLteOrNrBand
                            $cell.sinr = [int]$cell_value_arr[8] | Get-NrSinr
                            $cell.rsrp = [int]$cell_value_arr[10] | Get-NrRsrp
                            $cell.rsrq = [int]$cell_value_arr[11] | Get-NrRsrq
                        }
                    }

                    [PSCustomObject]$cell
                }
            }

            $ca_cells = @()
            $ca_match = [regex]::Match($response, "\+GTCAINFO:\s*(?<pcc>PCC:.+)\s*(?:(?<scc>SCC\s*[0-9]{1,}:.+)\s*){0,}")
            if ($ca_match.Success) {
                $cell = @{}
                $ca_value = $ca_match.Groups['pcc'].Value
                $ca_value_arr = $ca_value -split ':|,'

                $cell.primary = $true
                $cell.name = $ca_value_arr[0]
                $cell.upload = $true
                $cell.p_cell_id = [int]$ca_value_arr[2] | Get-PCellId
                $cell.arfcn = [int]$ca_value_arr[3]
                $cell.band = $cell.arfcn | Convert-ToLteOrNrBand
                $cell.dl_bandwidth = [int]$ca_value_arr[4] | Get-LteBandwidthFrequency
                $cell.ul_bandwidth = [int]$ca_value_arr[5] | Get-LteBandwidthFrequency
                $cell.dl_mimo = [int]$ca_value_arr[6]
                $cell.ul_mimo = [int]$ca_value_arr[7]
                $cell.dl_modulation = [int]$ca_value_arr[8] | Get-Modulation
                $cell.ul_modulation = [int]$ca_value_arr[9] | Get-Modulation

                $ca_cells += [PSCustomObject]$cell

                $cc_match.Groups['scc'].Captures

                $ca_cells += $ca_match.Groups['scc'].Captures | ForEach-Object {
                    $cell = @{}
                    $ca_value = $_.Value
                    $ca_value_arr = $ca_value -split ':|,'

                    $cell.primary = $false
                    $cell.name = $ca_value_arr[0]
                    $cell.upload = $ca_value_arr[2] -eq 1
                    $cell.p_cell_id = [int]$ca_value_arr[4] | Get-PCellId
                    $cell.arfcn = [int]$ca_value_arr[5]
                    $cell.band = $cell.arfcn | Convert-ToLteOrNrBand
                    $cell.dl_bandwidth = [int]$ca_value_arr[6] | Get-LteBandwidthFrequency
                    $cell.ul_bandwidth = [int]$ca_value_arr[7] | Get-LteBandwidthFrequency
                    $cell.dl_mimo = [int]$ca_value_arr[8]
                    $cell.ul_mimo = [int]$ca_value_arr[9]
                    $cell.dl_modulation = [int]$ca_value_arr[10] | Get-Modulation
                    $cell.ul_modulation = [int]$ca_value_arr[11] | Get-Modulation

                    [PSCustomObject]$cell
                }
            }


            ### Display
            $Host.UI.RawUI.CursorPosition = $statusCursorPosition

            $lineWidth = $Host.UI.RawUI.BufferSize.Width
            $titleWidth = 17

            Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1:%d} days {1:hh}:{1:mm}:{1:ss}" -f "Uptime:", ((Get-Date) - $scriptStartedAt)))

            if ($null -ne $temp) {
                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0} $([char]0xB0)C" -f "Temp:", $temp))
            }
            else {
                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4}" -f "Temp:", '--'))
            }

            Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1} ({2})" -f "Operator:", (Invoke-NullCoalescing $oper '----'), (Invoke-NullCoalescing $mode '--')))

            if ($null -ne $mode) {
                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}%   {2}" -f "Signal:", $csq_perc, (Get-Bars -Value $csq_perc -Min 0 -Max 100)))
            }

            $service_cell = $cc_cells | Where-Object { $_.is_service_cell } | Select-Object -First 1
            if ($service_cell) {
                if ($service_cell.rat -eq 'UMTS') {
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dBm {2}" -f "RSCP:", $service_cell.rscp, (Get-Bars -Value $service_cell.rscp -Min $rscp_min -Max $rscp_max)))
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dB  {2}" -f "ECNO:", $service_cell.ecno, (Get-Bars -Value $service_cell.ecno -Min $ecno_min -Max $ecno_max)))
                }
                elseif ($service_cell.rat -eq 'LTE') {
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dB  {2}" -f "SINR:", $service_cell.sinr, (Get-Bars -Value $service_cell.sinr -Min $lte_sinr_min -Max $lte_sinr_max)))
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dBm {2}" -f "RSRP:", $service_cell.rsrp, (Get-Bars -Value $service_cell.rsrp -Min $lte_rsrp_min -Max $lte_rsrp_max)))
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dB  {2}" -f "RSRQ:", $service_cell.rsrq, (Get-Bars -Value $service_cell.rsrq -Min $lte_rsrq_min -Max $lte_rsrq_max)))
                }
                elseif ($service_cell.rat -eq 'NR') {
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dB  {2}" -f "SINR:", $service_cell.sinr, (Get-Bars -Value $service_cell.sinr -Min $nr_sinr_min -Max $nr_sinr_max)))
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dBm {2}" -f "RSRP:", $service_cell.rsrp, (Get-Bars -Value $service_cell.rsrp -Min $nr_rsrp_min -Max $nr_rsrp_max)))
                    Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1,4:f0}dB  {2}" -f "RSRQ:", $service_cell.rsrq, (Get-Bars -Value $service_cell.rsrq -Min $nr_rsrq_min -Max $nr_rsrq_max)))
                }
            }

            if ($ca_cells.Length -gt 0) {
                $dl_bands = ($ca_cells | ForEach-Object {
                        $cell = $_
                        $cell_bandwidth = if ($cell.dl_bandwidth) { "@$($cell.dl_bandwidth)MHz" } else { '' }
                        "$($cell.band)$($cell_bandwidth)"
                    }) -join ' '
                $ul_bands = ($ca_cells | Where-Object { $_.upload } | ForEach-Object {
                        $cell = $_
                        $cell_bandwidth = if ($cell.ul_bandwidth) { "@$($cell.ul_bandwidth)MHz" } else { '' }
                        "$($cell.band)$($cell_bandwidth)"
                    }) -join ' '
                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} DL: {1}, UL: {2}" -f "Band:", $dl_bands, $ul_bands))
            }
            elseif ($service_cell) {
                $cell_bandwidth = if ($service_cell.bandwidth) { "@$($service_cell.bandwidth)MHz" } else { '' }
                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} {1}{2}" -f "Band:", $service_cell.band, $cell_bandwidth))
            }
            else {
                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth} --" -f "Band:"))
            }

            if ($cc_cells.Length -gt 0) {
                Write-Host ("{0,-$lineWidth}" -f ' ')
                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth}" -f "=== Cells ==="))

                foreach ($cell in $cc_cells) {
                    Write-Host -NoNewline ("Cell {0,-4} " -f $cell.rat)
                    Write-Host -NoNewline ("{0} {1,-9} " -f "CI:", $cell.cell_id)
                    if ($cell.rat -eq 'UMTS') {
                        Write-Host -NoNewline ("{0} {1,-5} " -f "PSC:", $cell.p_cell_id)
                        Write-Host -NoNewline ("{0} {1,-11} ({2,-5}) " -f "BAND (UARFCN):", $cell.band, $cell.arfcn)
                        Write-Host -NoNewline ("{0} {1,4:f0}dBm {2} " -f "RSCP:", $cell.rscp, (Get-Bars -Value $cell.rscp -Min $rscp_min -Max $rscp_max))
                        Write-Host -NoNewline ("{0} {1,4:f0}dB {2} " -f "ECNO:", $cell.ecno, (Get-Bars -Value $cell.ecno -Min $ecno_min -Max $ecno_max))
                    }
                    elseif ($cell.rat -eq 'LTE') {
                        Write-Host -NoNewline ("{0} {1,-5} " -f "PCI:", $cell.p_cell_id)
                        $cell_bandwidth = if ($cell.bandwidth) { "@$($cell.bandwidth)MHz" } else { '' }
                        Write-Host -NoNewline ("{0} {1,3}{2,-8} ({3,-5}) " -f "BAND (EARFCN):", $cell.band, $cell_bandwidth, $cell.arfcn)
                        Write-Host -NoNewline ("{0} {1,4:f0}dBm {2} " -f "RSRP:", $cell.rsrp, (Get-Bars -Value $cell.rsrp -Min $lte_rsrp_min -Max $lte_rsrp_max))
                        Write-Host -NoNewline ("{0} {1,4:f0}dB {2} " -f "RSRQ:", $cell.rsrq, (Get-Bars -Value $cell.rsrq -Min $lte_rsrq_min -Max $lte_rsrq_max))
                    }
                    elseif ($cell.rat -eq 'NR') {
                        Write-Host -NoNewline ("{0} {1,-5} " -f "PCI:", $cell.p_cell_id)
                        $cell_bandwidth = if ($cell.bandwidth) { "@$($cell.bandwidth)MHz" } else { '' }
                        Write-Host -NoNewline ("{0} {1,3}{2,-8} ({3,-5}) " -f "BAND (NARFCN):", $cell.band, $cell_bandwidth, $cell.arfcn)
                        Write-Host -NoNewline ("{0} {1,4:f0}dBm {2} " -f "RSRP:", $cell.rsrp, (Get-Bars -Value $cell.rsrp -Min $nr_rsrp_min -Max $nr_rsrp_max))
                        Write-Host -NoNewline ("{0} {1,4:f0}dB {2} " -f "RSRQ:", $cell.rsrq, (Get-Bars -Value $cell.rsrq -Min $nr_rsrq_min -Max $nr_rsrq_max))
                    }

                    $clearCount = $lineWidth - $Host.UI.RawUI.CursorPosition.X
                    Write-Host ("{0,-$clearCount}" -f '')
                }
            }

            if ($ca_cells.Length -gt 0) {
                Write-Host ("{0,-$lineWidth}" -f ' ')
                Write-Host ("{0,-$lineWidth}" -f ("{0,-$titleWidth}" -f "=== Carrier Aggregation ==="))

                foreach ($cell in $ca_cells) {
                    Write-Host -NoNewline ("{0,-6} " -f $cell.name)
                    Write-Host -NoNewline ("{0} {1,-5} " -f "PCI:", $cell.p_cell_id)
                    Write-Host -NoNewline ("{0} {1,3} ({2,-5}) " -f "BAND (EARFCN):", $cell.band, $cell.arfcn)
                    $cell_dl_bandwidth = if ($cell.dl_bandwidth) { "@$($cell.dl_bandwidth)MHz" } else { '' }
                    Write-Host -NoNewline ("{0} {1,7}{2,-8} " -f "DL:", $cell.dl_modulation, $cell_dl_bandwidth)
                    $cell_ul_bandwidth = if ($cell.ul_bandwidth) { "@$($cell.ul_bandwidth)MHz" } else { '' }
                    Write-Host -NoNewline ("{0} {1,7}{2,-8} " -f "UL:", $cell.ul_modulation, $cell_ul_bandwidth)

                    $clearCount = $lineWidth - $Host.UI.RawUI.CursorPosition.X
                    Write-Host ("{0,-$clearCount}" -f '')
                }
            }

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
        Write-Error2 "`n$_ `n$($_.FullyQualifiedErrorId) `n $($_.ScriptStackTrace)"
        Write-Verbose "`n$_ `n$($_.FullyQualifiedErrorId) `n $($_.ScriptStackTrace)"
    }
    finally {
        $Host.UI.RawUI.CursorSize = $defaultCursorSize
        Stop-NetworkMonitoring
        Stop-SerialPortMonitoring
        Get-Event -SourceIdentifier $watchdogEventSource -ErrorAction SilentlyContinue | Remove-Event
        if ($modem) {
            Close-SerialPort -Port $modem
            $modem.Dispose()
            $modem = $null
        }
    }
    Start-Sleep -Seconds 5
}

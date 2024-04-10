$port_commands_responses = @{
    "\+CGMI\?"          = "`r`n+CGMI: `"Fibocom Wireless Inc.`"`r`n";
    "\+FMM\?"           = "`r`n+FMM: `"FM350-GL-00 5G Module`",`"FM350-GL-00`"`r`n";
    "\+GTPKGVER\?"      = "`r`n+GTPKGVER: `"81600.0000.00.29.22.05_5000.0000.050.000.045_E05`"`r`n";
    "\+CFSN\?"          = "`r`n+CFSN: `"1234567890`"`r`n";
    "\+CGSN\?"          = "`r`n+CGSN: `"123456789012345`"`r`n";
    "\+CIMI\?"          = "`r`n+CIMI: `"123456789012345`"`r`n";
    "\+CCID\?"          = "`r`n+CCID: 12345678901234556789`r`n";
    "\+CPIN\?"          = "`r`n+CPIN: READY`r`n";
    "\+CGATT\?"         = "`r`n+CGATT: 1`r`n";

    "\+CSQ\?"           = "`r`n+CSQ: 14, 99`r`n";
    "\+COPS\?"          = "`r`n+COPS: 0,0,`"TEST`",7`r`n";
    "\+CGPADDR=\d+"     = "`r`n+CGPADDR: 1,`"10.0.0.1`",`"`"`r`n";
    "\+GTDNS=\d+"       = "`r`n+GTDNS: 1,`"10.0.0.2`",`"10.0.0.3`"`r`n";
    "\+SIMTYPE\?"       = "`r`n+SIMTYPE: 0`r`n";
    "\+GTDUALSIM\?"     = [scriptblock] {
        $r = @()
        $r += "`r`n+GTDUALSIM : 0, `"SUB1`", `"L`"`r`n"
        $r += "`r`n+GTDUALSIM : 1, `"SUB2`", `"N`"`r`n"
        return $r -join ''
    };
    "\+GTSENRDTEMP=\d+" = [scriptblock] {
        $v = Get-Random -Minimum 37000 -Maximum 70000
        return "`r`n+GTSENRDTEMP: 1,$v`r`n"
    };
    "\+GTCCINFO\?"      = [scriptblock] {
        $n = 15 #Get-Random -Minimum 0 -Maximum 15
        $r = @("`r`n+GTCCINFO: `r`n")
        if ($n -gt 0) {
            $r += "1,4,250,1,1234,001234567,1721,223,103,50,8,62,62,16`r`n"
        }
        if ($n -gt 1) {
            $r += "1,9,,,FFFFFFF,00FFFFFFF,723322,143,5079,500,12,67,67,81`r`n"
        }
        if ($n -gt 2) {
            $r += "2,4,,,FFFF,00FFFFFFF,1721,160,,55,55,2`r`n"
        }

        if ($n -gt 2) {
            $r += "1,2,250,1,1234,001234567,2987,92,8,22,40,,40,,`r`n"
        }

        if ($n -gt 2) {
            $r += "2,2,250,1,1234,001234567,2987,92,,,,22,,35,35`r`n"
        }

        return $r -join ''
    };
    "\+GTCAINFO\?"      = [scriptblock] {
        $n = 6 #Get-Random -Minimum 0 -Maximum 15
        $r = @("`r`n+GTCAINFO: `r`n")
        if ($n -gt 0) {
            $r += "PCC:5079,143,723322,500,500,3,1,1,3,-83`r`n"
        }
        if ($n -gt 1) {
            $r += "PCC:103,223,1721,50,50,2,1,3,3,-68`r`n"
        }
        if ($n -gt 2) {
            $r += "SCC 1:2,0,101,296,350,50,255,2,255,2,255,-68`r`n"
        }
        return $r -join ''
    };
}

function Get-SerialPort {
    param (
        [Parameter(Mandatory)]
        [string] $FriendlyName
    )
    return @('COM???', 'mock_container_id')
}

function New-SerialPort {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $port = [pscustomobject]@{
        IsOpen = $false;
    }

    $port | Add-Member -MemberType ScriptMethod -Name "Dispose" -Force -Value {
        $this.IsOpen = $false
    }

    return $port
}


function Open-SerialPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Port
    )
    $Port.IsOpen = $true
}

function Close-SerialPort {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [pscustomobject] $Port
    )
    $Port.IsOpen = $false
}

function Test-SerialPort {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [pscustomobject] $Port
    )

    if (-Not($Port.IsOpen)) {
        throw "Modem port is not opened."
    }
}

function Test-AtResponseError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Result
    )

    return ($Result -match "`r`n(ERROR|\+CME ERROR|\+CMS ERROR)")
}

function Test-AtResponseSuccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Result
    )

    return ($Result -match "`r`nOK")
}


function Send-ATCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [pscustomobject] $Port,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Command
    )

    $response = ''
    Write-Verbose "`r`n--> $Command"

    Test-SerialPort -Port $Port

    $cmd_list = $Command -split ';' | ForEach-Object {
        "$_".Trim()
    }

    foreach ($cmd in $cmd_list) {
        $port_commands_responses.Keys | ForEach-Object {
            $key = $_
            $value = $port_commands_responses[$key]
            if ($value.GetType() -eq [scriptblock]) {
                $value = Invoke-Command -ScriptBlock $value
            }

            if ($cmd -match $key) {
                $response += $value
            }
        }
    }

    $response += "`r`nOK`r`n"

    Write-Verbose (($response -split "`r`n" | Where-Object { $_ } | ForEach-Object { "<-- $_" }) -join "`r`n")

    $response
}

function Start-SerialPortMonitoring {
    param(
        [Parameter(Mandatory)]
        [string] $WatchdogSourceIdentifier,
        [Parameter(Mandatory)]
        [string] $FriendlyName
    )
    $null = Start-Job -Name "SerialPortMonitoring" -ArgumentList $WatchdogSourceIdentifier, $FriendlyName -InitializationScript $functions -ScriptBlock {
        param (
            [string] $WatchdogSourceIdentifier,
            [string] $FriendlyName
        )

        Import-Module "$($using:PWD)/modules/serial-port.psm1"

        Register-EngineEvent -SourceIdentifier $WatchdogSourceIdentifier -Forward
        Register-WMIEvent -SourceIdentifier "DeviceChangeEvent" -Query "SELECT * FROM Win32_DeviceChangeEvent WHERE EventType = 2 OR EventType = 3 GROUP WITHIN 2"

        try {
            while ($true) {
                try {
                    $e = Wait-Event -SourceIdentifier "DeviceChangeEvent"
                    if (-Not($e)) {
                        Start-Sleep -Seconds 1
                        continue
                    }
                    Remove-Event -EventIdentifier $e.EventIdentifier

                    # noop
                }
                catch { }
            }
        }
        finally {
            Unregister-Event -SourceIdentifier "DeviceChangeEvent" -Force -ErrorAction SilentlyContinue
        }
    }
}

function Stop-SerialPortMonitoring {
    Stop-Job -Name "SerialPortMonitoring" -PassThru -ErrorAction SilentlyContinue | Remove-Job | Out-Null
}

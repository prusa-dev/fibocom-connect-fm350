function Get-NetworkInterface {
    param(
        [Parameter(Mandatory)]
        [string] $ContainerId
    )

    $ncm1ifindex = Get-NetAdapter | Where-Object {
        ($null -ne $_.Status) -and `
        ((Get-PnpDeviceProperty -InstanceId $_.PnPDeviceID -KeyName DEVPKEY_Device_ContainerId -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Data) -eq $ContainerId)
    } | Select-Object -First 1 -ExpandProperty InterfaceIndex

    if ($ncm1ifindex) {
        return $ncm1ifindex
    }
    else {
        return $null
    }
}

function Initialize-Network {
    param(
        [Parameter(Mandatory)]
        [uint32] $InterfaceIndex,
        [Parameter(Mandatory)]
        [string] $IpAddress,
        [Parameter(Mandatory)]
        [string] $IpMask,
        [Parameter(Mandatory)]
        [string] $IpGateway,
        [Parameter(Mandatory)]
        [string[]] $IpDns
    )
    ### Setup IPv4 Network

    $ipPrefixLength = ([Convert]::ToString(([ipaddress]$IpMask).Address, 2) -replace 0, $null).Length
    $mac = Get-NetAdapter -ifIndex $InterfaceIndex | Select-Object -ExpandProperty MacAddress

    #### Adapter init
    Get-NetAdapter -ifIndex $InterfaceIndex | Enable-NetAdapter -Confirm:$false | Out-Null
    Get-NetAdapter -ifIndex $InterfaceIndex | Select-Object -Property name | Disable-NetAdapterBinding | Out-Null
    Get-NetAdapter -ifIndex $InterfaceIndex | Select-Object -Property name | Enable-NetAdapterBinding -ComponentID ms_tcpip | Out-Null

    #### Address cleanup
    Start-Sleep -Milliseconds 100
    Get-NetIPAddress -ifIndex $InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false | Out-Null
    Get-NetNeighbor -ifIndex $InterfaceIndex -LinkLayerAddress $mac -ErrorAction SilentlyContinue | Remove-NetNeighbor -Confirm:$false | Out-Null
    Get-NetRoute -ifIndex $InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false | Out-Null
    Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ResetServerAddresses -Confirm:$false | Out-Null

    ##### Address assign
    Start-Sleep -Milliseconds 100
    Set-NetIPInterface -ifIndex $InterfaceIndex -Dhcp Disabled
    New-NetIPAddress -ifIndex $InterfaceIndex -AddressFamily IPv4 -IPAddress $IpAddress -PrefixLength $ipPrefixLength -PolicyStore ActiveStore | Out-Null
    New-NetNeighbor -ifIndex $InterfaceIndex -AddressFamily IPv4 -IPAddress $IpAddress -LinkLayerAddress $mac | Out-Null
    New-NetNeighbor -ifIndex $InterfaceIndex -AddressFamily IPv4 -IPAddress $IpGateway -LinkLayerAddress $mac | Out-Null

    #### Add route
    Start-Sleep -Milliseconds 100
    New-NetRoute -ifIndex $InterfaceIndex -NextHop $IpGateway -DestinationPrefix "0.0.0.0/0" -RouteMetric 0 -PolicyStore ActiveStore | Out-Null

    #### Add DNS
    Start-Sleep -Milliseconds 100
    Set-DNSClient -InterfaceIndex $InterfaceIndex -RegisterThisConnectionsAddress $false | Out-Null
    Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses $IpDns | Out-Null
}

function Start-NetworkMonitoring {
    param(
        [Parameter(Mandatory)]
        [string] $WatchdogSourceIdentifier,
        [Parameter(Mandatory)]
        [string] $ContainerId
    )

    $null = Start-Job -Name "NetworkMonitoring" -ArgumentList $WatchdogSourceIdentifier, $ContainerId -InitializationScript $functions -ScriptBlock {
        param (
            [string] $WatchdogSourceIdentifier,
            [string] $ContainerId
        )

        Import-Module "$($using:PWD)/modules/network.psm1"

        Register-EngineEvent -SourceIdentifier $WatchdogSourceIdentifier -Forward
        Register-WMIEvent -SourceIdentifier "NetworkDisconnectEvent" -Namespace root\wmi -Class MSNdis_StatusMediaDisconnect

        try {
            while ($true) {
                try {
                    $e = Wait-Event -SourceIdentifier "NetworkDisconnectEvent"
                    if (-Not($e)) {
                        Start-Sleep -Seconds 1
                        continue
                    }
                    Remove-Event -EventIdentifier $e.EventIdentifier

                    $foundInterfaceIndex = Get-NetworkInterface -ContainerId $ContainerId
                    $foundInterfaceHasConnection = Get-NetConnectionProfile -InterfaceIndex $foundInterfaceIndex -IPv4Connectivity Internet -ErrorAction SilentlyContinue

                    if (-Not($foundInterfaceHasConnection)) {
                        New-Event -SourceIdentifier $WatchdogSourceIdentifier -Sender "NetworkMonitoring"  -MessageData "Disconnected"
                    }
                }
                catch {}
            }
        }
        finally {
            Unregister-Event -SourceIdentifier "NetworkDisconnectEvent" -Force -ErrorAction SilentlyContinue
        }
    }
}

function Stop-NetworkMonitoring {
    Stop-Job -Name "NetworkMonitoring" -PassThru -ErrorAction SilentlyContinue | Remove-Job | Out-Null
}

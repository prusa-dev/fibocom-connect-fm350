function Get-NetworkInterface {
    param(
        [Parameter(Mandatory)]
        [string] $ContainerId
    )

    return 1
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

    # noop
}

function Start-NetworkMonitoring {
    param(
        [Parameter(Mandatory)]
        [string] $WatchdogSourceIdentifier,
        [Parameter(Mandatory)]
        [string] $ContainerId
    )
    # noop
}

function Stop-NetworkMonitoring {
    # noop
}

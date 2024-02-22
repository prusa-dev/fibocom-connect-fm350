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

                    # noop

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

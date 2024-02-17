$ErrorActionPreference = 'Stop'

function Write-Error2 {
    param (
        [Parameter(Position = 0)]
        [string]$Message
    )
    Write-Host -BackgroundColor $Host.PrivateData.ErrorBackgroundColor -ForegroundColor $Host.PrivateData.ErrorForegroundColor $Message
}

function Wait-Action {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Message,
        [Parameter(Mandatory)]
        [scriptblock] $Action
    )

    $cursorSize = $Host.UI.RawUI.CursorSize; $Host.UI.RawUI.CursorSize = 0

    try {
        $messageLine = $Host.UI.RawUI.CursorPosition

        Write-Host

        $job = Start-ThreadJob -StreamingHost $Host -ScriptBlock {
            $messageLine = $using:messageLine
            $counter = 0
            while ($true) {
                $frame = $using:Message + ''.PadRight($counter % 4, '.')

                $currentLine = $Host.UI.RawUI.CursorPosition
                $Host.UI.RawUI.CursorPosition = $messageLine

                Write-Host "$frame".PadRight($Host.UI.RawUI.BufferSize.Width, ' ')

                $Host.UI.RawUI.CursorPosition = $currentLine

                $counter += 1
                Start-Sleep -Milliseconds 300 | Out-Null
            }
        }

        & $Action

        $job | Stop-Job -PassThru -ErrorAction SilentlyContinue | Remove-Job -Force | Out-Null
        $Host.UI.RawUI.CursorPosition = $messageLine
        Write-Host "$Message DONE!"
    }
    catch {
        $job | Stop-Job -PassThru -ErrorAction SilentlyContinue | Remove-Job -Force | Out-Null
        $Host.UI.RawUI.CursorPosition = $messageLine
        Write-Error2 "$Message ERROR!"
        throw
    }
    finally {
        $Host.UI.RawUI.CursorSize = $cursorSize
    }
}

function Awk {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string] $InputValue,
        [Parameter()]
        [regex] $Split = '\s',
        [Parameter(Mandatory)]
        [regex] $Filter,
        [Parameter(Mandatory)]
        [scriptblock] $Action
    )

    $InputValue -split "`r|`n" | Where-Object { $_ } | Select-String -Pattern $Filter | ForEach-Object {
        $actionArgs = $_ -split $Split
        Invoke-Command -ScriptBlock $Action -ArgumentList $actionArgs
    }
}

function Get-Bars {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [nullable[double]] $Value,
        [Parameter(Mandatory)]
        [double] $Min,
        [Parameter(Mandatory)]
        [double] $Max,
        [uint16] $BarWidth = 8
    )
    if ($null -eq $Value -or $Value -lt $Min ) { $Value = $Min }
    if ($Value -gt $Max ) { $Value = $Max }

    $bar_fill = [Math]::Abs([Math]::Round(($Value - $Min) / (($Max - $Min) / $BarWidth)))
    $bar_empty = $BarWidth - $bar_fill
    "[{0}{1}]" -f ("$([char]0x2588)" * $bar_fill), ("$([char]0x2591)" * $bar_empty)
}

function Invoke-Operand ($Command) {
    if ($Command -is [scriptblock]) {
        return Invoke-Command -ScriptBlock $Command -NoNewScope
    }

    return $Command
}

function Invoke-NullCoalescing {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [AllowNull()]
        [object]$LeftHand,

        [Parameter(Mandatory = $true, Position = 1)]
        [object]$RightHand
    )

    if ($Value = Invoke-Operand -Command $LeftHand) {
        return $Value
    }

    return Invoke-Operand -Command $RightHand
}

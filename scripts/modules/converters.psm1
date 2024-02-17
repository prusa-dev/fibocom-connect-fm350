function Get-BandLte {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Channel
    )

    process {
        if ($null -eq $Channel) {
            "--"
        }
        elseif ( $Channel -lt 600 ) {
            "B1"
        }
        elseif ( $Channel -lt 1200 ) {
            "B2"
        }
        elseif ( $Channel -lt 1950 ) {
            "B3"
        }
        elseif ( $Channel -lt 2400 ) {
            "B4"
        }
        elseif ( $Channel -lt 2650 ) {
            "B5"
        }
        elseif ( $Channel -lt 2750 ) {
            "B6"
        }
        elseif ( $Channel -lt 3450 ) {
            "B7"
        }
        elseif ( $Channel -lt 3800 ) {
            "B8"
        }
        elseif ( $Channel -lt 4150 ) {
            "B9"
        }
        elseif ( $Channel -lt 4750 ) {
            "B10"
        }
        elseif ( $Channel -lt 4950 ) {
            "B11"
        }
        elseif ( $Channel -lt 5010 ) {
            "--"
        }
        elseif ( $Channel -lt 5180 ) {
            "B12"
        }
        elseif ( $Channel -lt 5280 ) {
            "B13"
        }
        elseif ( $Channel -lt 5380 ) {
            "B14"
        }
        elseif ( $Channel -lt 5730 ) {
            "--"
        }
        elseif ( $Channel -lt 5850 ) {
            "B17"
        }
        elseif ( $Channel -lt 6000 ) {
            "B18"
        }
        elseif ( $Channel -lt 6150 ) {
            "B19"
        }
        elseif ( $Channel -lt 6450 ) {
            "B20"
        }
        elseif ( $Channel -lt 6600 ) {
            "B21"
        }
        elseif ( $Channel -lt 7400 ) {
            "B22"
        }
        elseif ( $Channel -lt 7500 ) {
            "--"
        }
        elseif ( $Channel -lt 7700 ) {
            "B23"
        }
        elseif ( $Channel -lt 8040 ) {
            "B24"
        }
        elseif ( $Channel -lt 8690 ) {
            "B25"
        }
        elseif ( $Channel -lt 9040 ) {
            "B26"
        }
        elseif ( $Channel -lt 9210 ) {
            "B27"
        }
        elseif ( $Channel -lt 9660 ) {
            "B28"
        }
        elseif ( $Channel -lt 9770 ) {
            "B29"
        }
        elseif ( $Channel -lt 9870 ) {
            "B30"
        }
        elseif ( $Channel -lt 9920 ) {
            "B31"
        }
        elseif ( $Channel -lt 10400 ) {
            "B32"
        }
        elseif ( $Channel -lt 36000 ) {
            "--"
        }
        elseif ( $Channel -lt 36200 ) {
            "B33"
        }
        elseif ( $Channel -lt 36350 ) {
            "B34"
        }
        elseif ( $Channel -lt 36950 ) {
            "B35"
        }
        elseif ( $Channel -lt 37550 ) {
            "B36"
        }
        elseif ( $Channel -lt 37750 ) {
            "B37"
        }
        elseif ( $Channel -lt 38250 ) {
            "B38"
        }
        elseif ( $Channel -lt 38650 ) {
            "B39"
        }
        elseif ( $Channel -lt 39650 ) {
            "B40"
        }
        elseif ( $Channel -lt 41590 ) {
            "B41"
        }
        elseif ( $Channel -lt 43590 ) {
            "B42"
        }
        elseif ( $Channel -lt 45590 ) {
            "B43"
        }
        elseif ( $Channel -lt 46590 ) {
            "B44"
        }
        elseif ( $Channel -lt 46790 ) {
            "B45"
        }
        elseif ( $Channel -lt 54540 ) {
            "B46"
        }
        elseif ( $Channel -lt 55240 ) {
            "B47"
        }
        elseif ( $Channel -lt 56740 ) {
            "B48"
        }
        elseif ( $Channel -lt 58240 ) {
            "B49"
        }
        elseif ( $Channel -lt 59090 ) {
            "B50"
        }
        elseif ( $Channel -lt 59140 ) {
            "B51"
        }
        elseif ( $Channel -lt 60140 ) {
            "B52"
        }
        elseif ( $Channel -lt 60255 ) {
            "B53"
        }
        elseif ( $Channel -lt 65536 ) {
            "--"
        }
        elseif ( $Channel -lt 66436 ) {
            "B65"
        }
        elseif ( $Channel -lt 67336 ) {
            "B66"
        }
        elseif ( $Channel -lt 67536 ) {
            "B67"
        }
        elseif ( $Channel -lt 67836 ) {
            "B68"
        }
        elseif ( $Channel -lt 68336 ) {
            "B69"
        }
        elseif ( $Channel -lt 68586 ) {
            "B70"
        }
        elseif ( $Channel -lt 68936 ) {
            "B71"
        }
        elseif ( $Channel -lt 68986 ) {
            "B72"
        }
        elseif ( $Channel -lt 69036 ) {
            "B73"
        }
        elseif ( $Channel -lt 69466 ) {
            "B74"
        }
        elseif ( $Channel -lt 70316 ) {
            "B75"
        }
        elseif ( $Channel -lt 70366 ) {
            "B76"
        }
        elseif ( $Channel -lt 70546 ) {
            "B85"
        }
        elseif ( $Channel -lt 70596 ) {
            "B87"
        }
        elseif ( $Channel -lt 70646 ) {
            "B88"
        }
        else {
            "--"
        }
    }
}

function Get-BandwidthFrequency {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Bandwidth
    )
    process {
        switch ($Bandwidth) {
            0 { 1.4 }
            1 { 3 }
            2 { 5 }
            3 { 10 }
            4 { 15 }
            5 { 20 }
            default { 0 }
        }
    }
}

function Convert-RsrpToRssi {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[double]] $Rsrp,
        [Parameter(Mandatory, Position = 1)]
        [AllowNull()]
        [nullable[int]] $Bandwidth
    )
    process {
        if ($null -eq $Rsrp -or $null -eq $Bandwidth) {
            $null
        }
        else {
            $np = switch ($Bandwidth) {
                0 { 6 }
                1 { 15 }
                2 { 25 }
                3 { 50 }
                4 { 75 }
                5 { 100 }
                default { 0 }
            }

            if ($np -gt 0) {
                $Rsrp + (10 * [Math]::Log10(12 * $np))
            }
            else {
                -113
            }
        }
    }
}

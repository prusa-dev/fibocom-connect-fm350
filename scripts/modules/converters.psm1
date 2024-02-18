function Get-Rat {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )
    process {
        switch ($Value) {
            2 { 'UMTS' }
            4 { 'LTE' }
            9 { 'NR' }
            default { '--' }
        }
    }
}

function Get-CellId {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )
    process {
        if ($null -eq $Value -or $Value -ge 0x0FFFFFFF) {
            return '--'
        }

        return $Value
    }
}

function Get-PCellId {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )
    process {
        if ($null -eq $Value -or $Value -ge 0xFFFFF) {
            return '--'
        }

        return $Value
    }
}

function Get-TacOrLac {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )
    process {
        if ($null -eq $Value -or $Value -ge 0xFFFF) {
            return '--'
        }

        return $Value
    }
}

function Get-UmtsBand {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    if ($null -eq $Value -or $Value -eq 0) {
        return '--'
    }

    return "B$($Value)"
}

function Get-UmtsEcno {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    return $Value / 2 - 24
}

function Get-UmtsRscp {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    return $Value - 121
}


function Get-LteBandwidthFrequency {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Bandwidth
    )
    process {
        switch ($Bandwidth) {
            6 { 1.4 }
            15 { 3 }
            25 { 5 }
            50 { 10 }
            75 { 15 }
            100 { 20 }
            default { 0 }
        }
    }
}

function Get-LteRsrp {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    process {
        if ($null -eq $Value -or $Value -eq 255) {
            return $null
        }

        return $Value - 141
    }
}

function Get-LteRsrq {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    process {
        if ($null -eq $Value -or $Value -eq 255) {
            return $null
        }

        return $Value / 2 - 20
    }
}

function Get-LteSinr {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    process {
        if ($null -eq $Value) {
            return $null
        }

        return $Value / 2
    }
}

function Get-NrBandwidthFrequency {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Bandwidth
    )
    process {
        switch ($Bandwidth) {
            25 { 5 }
            50 { 10 }
            75 { 15 }
            100 { 20 }
            125 { 25 }
            150 { 30 }
            200 { 40 }
            250 { 50 }
            300 { 60 }
            400 { 80 }
            450 { 90 }
            500 { 100 }
            1000 { 200 }
            2000 { 400 }
            default { 0 }
        }
    }
}

function Get-NrRsrp {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    process {
        if ($null -eq $Value -or $Value -eq 255) {
            return $null
        }

        return $Value - 157
    }
}

function Get-NrRsrq {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    process {
        if ($null -eq $Value -or $Value -eq 255) {
            return $null
        }

        return $Value / 2 - 44
    }
}

function Get-NrSinr {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    process {
        if ($null -eq $Value) {
            return $null
        }

        return $Value / 2 - 24
    }
}

function Get-Modulation {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )

    process {
        if ($null -eq $Value) {
            return $null
        }

        switch ($Value) {
            0 { 'BPSK' }
            1 { 'QPSK' }
            2 { '16QAM' }
            3 { '64QAM' }
            4 { '256QAM' }
            5 { '1024QAM' }
            default { $null }
        }
    }
}


function Convert-ToLteOrNrBand {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [nullable[int]] $Value
    )
    process {
        if ( $null -eq $Value) {
            '--'
        }
        elseif ( $Value -lt 600 ) {
            'B1'
        }
        elseif ( $Value -lt 1200 ) {
            'B2'
        }
        elseif ( $Value -lt 1950 ) {
            'B3'
        }
        elseif ( $Value -lt 2400 ) {
            'B4'
        }
        elseif ( $Value -lt 2650 ) {
            'B5'
        }
        elseif ( $Value -lt 2750 ) {
            'B6'
        }
        elseif ( $Value -lt 3450 ) {
            'B7'
        }
        elseif ( $Value -lt 3800 ) {
            'B8'
        }
        elseif ( $Value -lt 4150 ) {
            'B9'
        }
        elseif ( $Value -lt 4750 ) {
            'B10'
        }
        elseif ( $Value -lt 4950 ) {
            'B11'
        }
        elseif ( $Value -lt 5010 ) {
            '--'
        }
        elseif ( $Value -lt 5180 ) {
            'B12'
        }
        elseif ( $Value -lt 5280 ) {
            'B13'
        }
        elseif ( $Value -lt 5380 ) {
            'B14'
        }
        elseif ( $Value -lt 5730 ) {
            '--'
        }
        elseif ( $Value -lt 5850 ) {
            'B17'
        }
        elseif ( $Value -lt 6000 ) {
            'B18'
        }
        elseif ( $Value -lt 6150 ) {
            'B19'
        }
        elseif ( $Value -lt 6450 ) {
            'B20'
        }
        elseif ( $Value -lt 6600 ) {
            'B21'
        }
        elseif ( $Value -lt 7400 ) {
            'B22'
        }
        elseif ( $Value -lt 7500 ) {
            '--'
        }
        elseif ( $Value -lt 7700 ) {
            'B23'
        }
        elseif ( $Value -lt 8040 ) {
            'B24'
        }
        elseif ( $Value -lt 8690 ) {
            'B25'
        }
        elseif ( $Value -lt 9040 ) {
            'B26'
        }
        elseif ( $Value -lt 9210 ) {
            'B27'
        }
        elseif ( $Value -lt 9660 ) {
            'B28'
        }
        elseif ( $Value -lt 9770 ) {
            'B29'
        }
        elseif ( $Value -lt 9870 ) {
            'B30'
        }
        elseif ( $Value -lt 9920 ) {
            'B31'
        }
        elseif ( $Value -lt 10400 ) {
            'B32'
        }
        elseif ( $Value -lt 36000 ) {
            '--'
        }
        elseif ( $Value -lt 36200 ) {
            'B33'
        }
        elseif ( $Value -lt 36350 ) {
            'B34'
        }
        elseif ( $Value -lt 36950 ) {
            'B35'
        }
        elseif ( $Value -lt 37550 ) {
            'B36'
        }
        elseif ( $Value -lt 37750 ) {
            'B37'
        }
        elseif ( $Value -lt 38250 ) {
            'B38'
        }
        elseif ( $Value -lt 38650 ) {
            'B39'
        }
        elseif ( $Value -lt 39650 ) {
            'B40'
        }
        elseif ( $Value -lt 41590 ) {
            'B41'
        }
        elseif ( $Value -lt 43590 ) {
            'B42'
        }
        elseif ( $Value -lt 45590 ) {
            'B43'
        }
        elseif ( $Value -lt 46590 ) {
            'B44'
        }
        elseif ( $Value -lt 46790 ) {
            'B45'
        }
        elseif ( $Value -lt 54540 ) {
            'B46'
        }
        elseif ( $Value -lt 55240 ) {
            'B47'
        }
        elseif ( $Value -lt 56740 ) {
            'B48'
        }
        elseif ( $Value -lt 58240 ) {
            'B49'
        }
        elseif ( $Value -lt 59090 ) {
            'B50'
        }
        elseif ( $Value -lt 59140 ) {
            'B51'
        }
        elseif ( $Value -lt 60140 ) {
            'B52'
        }
        elseif ( $Value -lt 60255 ) {
            'B53'
        }
        elseif ( $Value -lt 65536 ) {
            '--'
        }
        elseif ( $Value -lt 66436 ) {
            'B65'
        }
        elseif ( $Value -lt 67336 ) {
            'B66'
        }
        elseif ( $Value -lt 67536 ) {
            'B67'
        }
        elseif ( $Value -lt 67836 ) {
            'B68'
        }
        elseif ( $Value -lt 68336 ) {
            'B69'
        }
        elseif ( $Value -lt 68586 ) {
            'B70'
        }
        elseif ( $Value -lt 68936 ) {
            'B71'
        }
        elseif ( $Value -lt 68986 ) {
            'B72'
        }
        elseif ( $Value -lt 69036 ) {
            'B73'
        }
        elseif ( $Value -lt 69466 ) {
            'B74'
        }
        elseif ( $Value -lt 70316 ) {
            'B75'
        }
        elseif ( $Value -lt 70366 ) {
            'B76'
        }
        elseif ( $Value -lt 70546 ) {
            'B85'
        }
        elseif ( $Value -lt 70596 ) {
            'B87'
        }
        elseif ( $Value -lt 70646 ) {
            'B88'
        }
        elseif ( $Value -le 123400 ) {
            '--'
        }
        elseif ( $Value -le 130400 ) {
            'n71'
        }
        elseif ( $Value -le 143400 ) {
            '--'
        }
        elseif ( $Value -le 145600 ) {
            'n29'
        }
        elseif ( $Value -le 145800 ) {
            '--'
        }
        elseif ( $Value -le 149200 ) {
            'n12'
        }
        elseif ( $Value -le 151600 ) {
            '--'
        }
        elseif ( $Value -le 153600 ) {
            'n14|n28'
        }
        elseif ( $Value -le 158200 ) {
            'n28'
        }
        elseif ( $Value -le 160600 ) {
            'n20|n28'
        }
        elseif ( $Value -le 164200 ) {
            'n20'
        }
        elseif ( $Value -le 171800 ) {
            '--'
        }
        elseif ( $Value -le 172000 ) {
            'n26'
        }
        elseif ( $Value -le 173800 ) {
            'n18|n26'
        }
        elseif ( $Value -le 175000 ) {
            'n5|n18|n26'
        }
        elseif ( $Value -le 178800 ) {
            'n5|n26'
        }
        elseif ( $Value -le 185000 ) {
            '--'
        }
        elseif ( $Value -le 192000 ) {
            'n8'
        }
        elseif ( $Value -le 285400 ) {
            '--'
        }
        elseif ( $Value -le 286400 ) {
            'n51|n76|n91|n93'
        }
        elseif ( $Value -le 295000 ) {
            'n50|n75|n92|n94'
        }
        elseif ( $Value -le 303400 ) {
            'n50|n74|n75|n92|n94'
        }
        elseif ( $Value -le 303600 ) {
            'n74'
        }
        elseif ( $Value -le 361000 ) {
            '--'
        }
        elseif ( $Value -le 376000 ) {
            'n3'
        }
        elseif ( $Value -le 384000 ) {
            'n39'
        }
        elseif ( $Value -le 386000 ) {
            '--'
        }
        elseif ( $Value -le 398000 ) {
            'n2|n25'
        }
        elseif ( $Value -le 399000 ) {
            'n25'
        }
        elseif ( $Value -le 402000 ) {
            'n70'
        }
        elseif ( $Value -le 404000 ) {
            'n34|n70'
        }
        elseif ( $Value -le 405000 ) {
            'n34'
        }
        elseif ( $Value -le 422000 ) {
            '--'
        }
        elseif ( $Value -le 434000 ) {
            'n1|n65|n66'
        }
        elseif ( $Value -le 440000 ) {
            'n65|n66'
        }
        elseif ( $Value -le 460000 ) {
            '--'
        }
        elseif ( $Value -le 470000 ) {
            'n40'
        }
        elseif ( $Value -le 472000 ) {
            'n30|n40'
        }
        elseif ( $Value -le 480000 ) {
            'n40'
        }
        elseif ( $Value -le 496700 ) {
            '--'
        }
        elseif ( $Value -le 499000 ) {
            'n53'
        }
        elseif ( $Value -le 499200 ) {
            '--'
        }
        elseif ( $Value -le 514000 ) {
            'n41|n90'
        }
        elseif ( $Value -le 524000 ) {
            'n38|n41|n90'
        }
        elseif ( $Value -le 538000 ) {
            'n7|n90'
        }
        elseif ( $Value -le 620000 ) {
            '--'
        }
        elseif ( $Value -le 636667 ) {
            'n77|n78'
        }
        elseif ( $Value -le 646666 ) {
            'n48|n77|n78'
        }
        elseif ( $Value -le 653333 ) {
            'n77|n78'
        }
        elseif ( $Value -le 680000 ) {
            'n77'
        }
        elseif ( $Value -le 693334 ) {
            '--'
        }
        elseif ( $Value -le 733333 ) {
            'n79'
        }
        else {
            '--'
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

function Get-ToolkitReportPath {
    [CmdletBinding()]
    param()

    if (-not $Global:ToolkitRunPath) {
        $root = Split-Path -Parent $PSScriptRoot
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

        $Global:ToolkitRunPath = Join-Path `
            $root `
            "Reports\Run_$timestamp"
    }

    if (-not (Test-Path $Global:ToolkitRunPath)) {
        New-Item `
            -ItemType Directory `
            -Path $Global:ToolkitRunPath `
            -Force |
            Out-Null
    }

    return $Global:ToolkitRunPath
}

function Save-TextReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Command
    )

    $reportPath = Get-ToolkitReportPath
    $path = Join-Path $reportPath "$Name.txt"

    Write-Log "Creating report: $Name"

    try {
        & $Command |
            Out-File `
                -FilePath $path `
                -Encoding utf8 `
                -Width 300
    }
    catch {
        "ERROR creating report: $Name" |
            Out-File `
                -FilePath $path `
                -Encoding utf8

        $_ |
            Out-File `
                -FilePath $path `
                -Append `
                -Encoding utf8
    }

    return $path
}

function Save-CsvReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Data
    )

    $reportPath = Get-ToolkitReportPath
    $path = Join-Path $reportPath "$Name.csv"

    $Data |
        Export-Csv `
            -Path $path `
            -NoTypeInformation `
            -Encoding utf8

    return $path
}

function Save-JsonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Data,

        [ValidateRange(2, 100)]
        [int]$Depth = 10
    )

    $reportPath = Get-ToolkitReportPath
    $path = Join-Path $reportPath "$Name.json"

    $Data |
        ConvertTo-Json `
            -Depth $Depth |
        Set-Content `
            -Path $path `
            -Encoding utf8

    return $path
}

function Save-HtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Html
    )

    $reportPath = Get-ToolkitReportPath
    $path = Join-Path $reportPath "$Name.html"

    Set-Content `
        -Path $path `
        -Value $Html `
        -Encoding utf8

    return $path
}

function Save-TextReport {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    if (-not (Test-Path $Global:ToolkitRunPath)) {
        New-Item -ItemType Directory -Path $Global:ToolkitRunPath -Force | Out-Null
    }

    $path = Join-Path $Global:ToolkitRunPath "$Name.txt"
    Write-Log "Creating report: $Name"

    try {
        & $Command | Out-File -FilePath $path -Encoding UTF8 -Width 300
    }
    catch {
        "ERROR creating report: $Name" | Out-File $path -Encoding UTF8
        $_ | Out-File $path -Append -Encoding UTF8
    }
}

function Save-CsvReport {
    param(
        [string]$Name,
        [object[]]$Data
    )

    if (-not (Test-Path $Global:ToolkitRunPath)) {
        New-Item -ItemType Directory -Path $Global:ToolkitRunPath -Force | Out-Null
    }

    $path = Join-Path $Global:ToolkitRunPath "$Name.csv"
    $Data | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
}

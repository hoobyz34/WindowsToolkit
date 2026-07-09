function Save-TextReport {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    $path = Join-Path $Global:ToolkitRunPath "$Name.txt"
    Write-Log "Creating report: $Name"

    try {
        & $Command | Out-File -FilePath $path -Encoding UTF8 -Width 300
    }
    catch {
        "ERROR creating report: $Name" | Out-File $path
        $_ | Out-File $path -Append
    }
}

function Save-CsvReport {
    param(
        [string]$Name,
        [object[]]$Data
    )

    $path = Join-Path $Global:ToolkitRunPath "$Name.csv"
    $Data | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
}

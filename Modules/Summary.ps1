$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Summary.psm1" -Force

Write-Section "Inventory Summary"

$reportPath = Get-ToolkitReportPath

$summary = Get-ToolkitInventorySummary `
    -ReportPath $reportPath

$summaryRows = ConvertTo-ToolkitSummaryRows `
    -Summary $summary

$jsonPath = Save-JsonReport `
    -Name "Inventory_Summary" `
    -Data $summary `
    -Depth 10

$csvPath = Save-CsvReport `
    -Name "Inventory_Summary" `
    -Data $summaryRows

Write-Host ""
Write-Host "Reports analyzed: $($summary.ReportCount)"
Write-Host "Inventory items: $($summary.TotalItems)"

Write-Host ""
Write-Host "Items by type:"

if ($summary.Types.Count -gt 0) {
    $summary.Types |
        Format-Table `
            -Property Name, Count `
            -AutoSize |
        Out-Host
}
else {
    Write-Info "No analyzer CSV reports were found in this run."
}

Write-Host ""
Write-Host "Top vendors:"

$summary.Vendors |
    Select-Object -First 10 |
    Format-Table `
        -Property Name, Count `
        -AutoSize |
    Out-Host

Write-Host ""
Write-Host "Recommendations:"

$summary.Recommendations |
    Format-Table `
        -Property Name, Count `
        -AutoSize |
    Out-Host

Write-Success "Inventory Summary complete."
Write-Host "CSV summary: $csvPath"
Write-Host "JSON summary: $jsonPath"

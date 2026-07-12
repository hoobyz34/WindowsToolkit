$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Summary.psm1" -Force
Import-Module "$Root\Core\Health.psm1" -Force

Write-Section "Inventory Health Score"

$reportPath = Get-ToolkitReportPath

$findings = @(
    Get-ToolkitReportFindings `
        -ReportPath $reportPath
)

$healthScore = Get-ToolkitInventoryHealthScore `
    -Findings $findings

$rows = ConvertTo-ToolkitHealthScoreRows `
    -HealthScore $healthScore

$csvPath = Save-CsvReport `
    -Name "Health_Score" `
    -Data $rows

$jsonPath = Save-JsonReport `
    -Name "Health_Score" `
    -Data $healthScore `
    -Depth 10

Write-Host ""
Write-Host "Assessment score: $($healthScore.Score)/100"
Write-Host "Status: $($healthScore.Status)"
Write-Host "Inventory items: $($healthScore.TotalItems)"
Write-Host "Complete findings: $($healthScore.CompleteItems)"
Write-Host "Coverage: $($healthScore.CoveragePercent)%"
Write-Host "Items requiring review: $($healthScore.ReviewItems)"
Write-Host (
    "High-risk review items: " +
    $healthScore.HighRiskReviewItems
)

Write-Host ""
Write-Host "Score components:"

$healthScore.Components |
    Select-Object `
        Name,
        Points,
        Maximum,
        Percentage |
    Format-Table -AutoSize |
    Out-Host

Write-Host "Assessment factors:"

foreach ($factor in @($healthScore.Factors)) {
    Write-Host " - $factor"
}

Write-Host ""
Write-Info $healthScore.Explanation
Write-Success "Inventory Health Score complete."
Write-Host "CSV report: $csvPath"
Write-Host "JSON report: $jsonPath"

$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Summary.psm1" -Force
Import-Module "$Root\Core\Correlation.psm1" -Force

Write-Section "Cross-Analyzer Correlation"

$reportPath = Get-ToolkitReportPath

$findings = @(
    Get-ToolkitReportFindings `
        -ReportPath $reportPath |
        Where-Object {
            $_.Type -ne "Correlation"
        }
)

if ($findings.Count -eq 0) {
    Write-WarningMessage (
        "No analyzer reports are available. " +
        "Run inventory analyzers before correlation."
    )
}

$correlations = @(
    Invoke-ToolkitCorrelation `
        -Findings $findings
)

$csvPath = Save-CsvReport `
    -Name "Correlation_Report" `
    -Data $correlations

$jsonPath = Save-JsonReport `
    -Name "Correlation_Report" `
    -Data $correlations `
    -Depth 10

Write-Host ""
Write-Host "Inventory findings analyzed: $($findings.Count)"
Write-Host "System observations: $($correlations.Count)"

if ($correlations.Count -gt 0) {
    Write-Host ""

    $correlations |
        Select-Object `
            Name,
            Category,
            Recommendation,
            Risk,
            EvidenceCount |
        Format-Table -AutoSize |
        Out-Host
}
else {
    Write-Info "No correlation rules matched the current inventory."
}

Write-Success "Cross-Analyzer Correlation complete."
Write-Host "CSV report: $csvPath"
Write-Host "JSON report: $jsonPath"

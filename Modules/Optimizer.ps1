$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Summary.psm1" -Force
Import-Module "$Root\Core\Optimizer.psm1" -Force

Write-Section "Safe Optimizer Plan"

$reportPath = Get-ToolkitReportPath
$findings = @(Get-ToolkitReportFindings -ReportPath $reportPath)
$plan = @(New-ToolkitOptimizationPlan -Findings $findings)

if ($findings.Count -eq 0) {
    Write-WarningMessage "No analyzer findings are available. Run inventory analyzers before creating an optimization plan."
}

$reportPaths = Save-ToolkitOptimizationPlanReports -Plan $plan

Write-Host ""
Write-Host "Findings planned: $($findings.Count)"
Write-Host "Plan entries: $($plan.Count)"
Write-Host "CSV plan: $($reportPaths.CsvPath)"
Write-Host "JSON plan: $($reportPaths.JsonPath)"
Write-Info "This module only creates a reviewable plan and does not change the system."
Write-Success "Safe Optimizer Plan complete."

$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Summary.psm1" -Force
Import-Module "$Root\Core\Optimizer.psm1" -Force

Write-Section "Safe Optimizer Plan"

$reportPath = Get-ToolkitReportPath
$findings = @(Get-ToolkitReportFindings -ReportPath $reportPath)
$plan = @(New-ToolkitOptimizationPlan -Findings $findings)
$preflightEnvironment = Get-ToolkitPreflightEnvironment
$preflight = @(
    New-ToolkitOptimizationPreflight `
        -PlanEntries $plan `
        -Environment $preflightEnvironment
)
$rollbackManifest = @(
    New-ToolkitRollbackManifest `
        -PlanEntries $plan `
        -PreflightResults $preflight
)

if ($findings.Count -eq 0) {
    Write-WarningMessage "No analyzer findings are available. Run inventory analyzers before creating an optimization plan."
}

$reportPaths = Save-ToolkitOptimizationPlanReports -Plan $plan
$preflightPaths = Save-ToolkitOptimizationPreflightReports `
    -PreflightResults $preflight
$rollbackPaths = Save-ToolkitRollbackManifestReports `
    -RollbackManifest $rollbackManifest

Write-Host ""
Write-Host "Findings planned: $($findings.Count)"
Write-Host "Plan entries: $($plan.Count)"
Write-Host "Preflight eligible: $(@($preflight | Where-Object IsEligible).Count)"
Write-Host "Preflight blocked: $(@($preflight | Where-Object IsBlocked).Count)"
Write-Host "CSV plan: $($reportPaths.CsvPath)"
Write-Host "JSON plan: $($reportPaths.JsonPath)"
Write-Host "CSV preflight: $($preflightPaths.CsvPath)"
Write-Host "JSON preflight: $($preflightPaths.JsonPath)"
Write-Host "CSV rollback manifest: $($rollbackPaths.CsvPath)"
Write-Host "JSON rollback manifest: $($rollbackPaths.JsonPath)"
Write-Info "This module only validates and reports; it does not change the system or create restore points."
Write-Success "Safe Optimizer Plan complete."

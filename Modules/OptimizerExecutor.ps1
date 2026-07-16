[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [switch]$Apply,
    [switch]$Confirmed
)

$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Optimizer.psm1" -Force
Import-Module "$Root\Core\OptimizerExecutor.psm1" -Force

Write-Section "Safe Optimizer Executor"

$reportPath = Get-ToolkitReportPath
$planPath = Join-Path $reportPath "Optimization_Plan.json"
$preflightPath = Join-Path $reportPath "Optimization_Preflight.json"
$rollbackPath = Join-Path $reportPath "Rollback_Manifest.json"
$requiredPaths = @($planPath, $preflightPath, $rollbackPath)
$missingPaths = @($requiredPaths | Where-Object { -not (Test-Path $_) })

if ($missingPaths.Count -gt 0) {
    Write-WarningMessage "Optimizer plan, preflight, and rollback reports are required. Run Safe Optimizer Plan first."
    return
}

$plan = @(Get-Content -Path $planPath -Raw | ConvertFrom-Json -ErrorAction Stop)
$preflight = @(
    Get-Content -Path $preflightPath -Raw |
        ConvertFrom-Json -ErrorAction Stop
)
$rollbackManifest = @(
    Get-Content -Path $rollbackPath -Raw |
        ConvertFrom-Json -ErrorAction Stop
)
$environment = Get-ToolkitPreflightEnvironment
$executionParameters = @{
    PlanEntries     = $plan
    PreflightResults = $preflight
    RollbackManifest = $rollbackManifest
    Apply           = $Apply
    Confirmed       = $Confirmed
    Environment     = $environment
}

if ($WhatIfPreference) {
    $executionParameters.WhatIf = $true
}

if ($PSBoundParameters.ContainsKey("Confirm")) {
    $executionParameters.Confirm = $PSBoundParameters["Confirm"]
}

$executionResults = @(
    Invoke-ToolkitOptimizationExecutor @executionParameters
)
$executionPaths = Save-ToolkitOptimizationExecutionReports `
    -ExecutionResults $executionResults

Write-Host ""
Write-Host "Attempt mode: $(if ($Apply) { 'Apply' } else { 'DryRun' })"
Write-Host "Actions reviewed: $($executionResults.Count)"
Write-Host "Previewed: $(@($executionResults | Where-Object Status -eq 'Preview').Count)"
Write-Host "Denied: $(@($executionResults | Where-Object Status -eq 'Denied').Count)"
Write-Host "Executed: $(@($executionResults | Where-Object Status -eq 'Executed').Count)"
Write-Host "CSV execution audit: $($executionPaths.CsvPath)"
Write-Host "JSON execution audit: $($executionPaths.JsonPath)"

if ($Apply) {
    Write-WarningMessage "Apply mode was explicitly requested; only confirmed, allowlisted, fully gated actions can execute."
}
else {
    Write-Info "Dry-run is the default. No optimization action was executed."
}

Write-Success "Safe Optimizer Executor complete."

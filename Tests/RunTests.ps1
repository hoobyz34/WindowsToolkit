[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "========================================="
Write-Host " Running WindowsToolkit Test Suite"
Write-Host "========================================="
Write-Host ""

Import-Module Pester `
    -MinimumVersion 5.0 `
    -ErrorAction Stop

$result = Invoke-Pester `
    -Path "$Root\Tests" `
    -PassThru

Write-Host ""

if ($result.Result -ne "Passed") {
    throw (
        "WindowsToolkit tests failed. " +
        "Passed: $($result.PassedCount), " +
        "Failed: $($result.FailedCount), " +
        "Skipped: $($result.SkippedCount)"
    )
}

Write-Host (
    "Test run passed. " +
    "Passed: $($result.PassedCount), " +
    "Failed: $($result.FailedCount)"
)

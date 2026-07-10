[CmdletBinding()]
param()

$Root = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "========================================="
Write-Host " Running WindowsToolkit Test Suite"
Write-Host "========================================="
Write-Host ""

Invoke-Pester "$Root\Tests"

Write-Host ""
Write-Host "Test run complete."
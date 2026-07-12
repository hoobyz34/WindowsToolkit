$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Version.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Summary.psm1" -Force
Import-Module "$Root\Core\Dashboard.psm1" -Force

Write-Section "HTML Inventory Dashboard"

$reportPath = Get-ToolkitReportPath

$summary = Get-ToolkitInventorySummary `
    -ReportPath $reportPath

$html = New-ToolkitHtmlDashboard `
    -Summary $summary `
    -ToolkitVersion (Get-ToolkitVersion) `
    -ComputerName $env:COMPUTERNAME

$dashboardPath = Save-HtmlReport `
    -Name "Inventory_Dashboard" `
    -Html $html

Write-Success "HTML Inventory Dashboard complete."
Write-Host "Dashboard saved to: $dashboardPath"

if ($IsWindows -and (Test-Path $dashboardPath)) {
    Start-Process $dashboardPath
}

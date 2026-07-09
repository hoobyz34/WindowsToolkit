param()

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$ScriptRoot\Core\Logger.psm1" -Force
Import-Module "$ScriptRoot\Core\Utility.psm1" -Force
Import-Module "$ScriptRoot\Core\Reporting.psm1" -Force

Initialize-ToolkitSession

function Show-Menu {
    Clear-Host
    Write-Host "========================================="
    Write-Host " WindowsToolkit v0.1.0"
    Write-Host "========================================="
    Write-Host "1. System Audit"
    Write-Host "2. Service Analyzer"
    Write-Host "3. Exit"
    Write-Host ""
}

do {
    Show-Menu
    $choice = Read-Host "Choose an option"

    switch ($choice) {
        "1" {
            & "$ScriptRoot\Modules\Audit.ps1"
            Pause
        }
        "2" {
            & "$ScriptRoot\Modules\Services.ps1"
            Pause
        }
        "3" {
            Write-Host "Exiting."
            break
        }
        default {
            Write-Host "Invalid choice."
            Pause
        }
    }
} while ($choice -ne "3")
param()

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$ScriptRoot\Core\Version.psm1" -Force
Import-Module "$ScriptRoot\Core\Console.psm1" -Force
Import-Module "$ScriptRoot\Core\Logger.psm1" -Force
Import-Module "$ScriptRoot\Core\Utility.psm1" -Force
Import-Module "$ScriptRoot\Core\Reporting.psm1" -Force
Import-Module "$ScriptRoot\Core\Models.psm1" -Force
Import-Module "$ScriptRoot\Core\Discovery.psm1" -Force

Initialize-ToolkitSession

function Show-Menu {
    Show-ToolkitHeader
    Write-Host "1. System Audit"
    Write-Host "2. Service Analyzer"
    Write-Host "3. Startup Analyzer"
    Write-Host "4. Installed Software"
    Write-Host "5. HP Analyzer"
    Write-Host "6. Driver Analyzer"
    Write-Host "7. Scheduled Task Analyzer"
    Write-Host "8. Windows Features Analyzer"
    Write-Host "9. Appx Package Analyzer"
    Write-Host "10. Exit"
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
            & "$ScriptRoot\Modules\Startup.ps1"
            Pause
        }
        "4" {
            & "$ScriptRoot\Modules\Software.ps1"
            Pause
        }
        "5" {
            & "$ScriptRoot\Modules\HP.ps1"
            Pause
        }
        "6" {
            & "$ScriptRoot\Modules\Drivers.ps1"
            Pause
        }
        "7" {
            & "$ScriptRoot\Modules\ScheduledTasks.ps1"
            Pause
        }
        "8" {
            & "$ScriptRoot\Modules\WindowsFeatures.ps1"
            Pause
        }
        "9" {
            & "$ScriptRoot\Modules\AppxPackages.ps1"
            Pause
        }
        "10" {
            Write-Host "Exiting."
            break
        }
        default {
            Write-Host "Invalid choice."
            Pause
        }
    }
} while ($choice -ne "10")

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
Write-Host "6. Exit"
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
            Write-Host "Exiting."
            break
        }
        default {
            Write-Host "Invalid choice."
            Pause
        }
    }
} while ($choice -ne "6")
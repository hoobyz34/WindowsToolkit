$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Models.psm1" -Force
Import-Module "$Root\Core\Discovery.psm1" -Force

Write-Section "HP Analyzer"

function Get-HPClassification {
    param(
        [string]$Name,
        [string]$Type
    )

    $text = "$Name $Type"

    if ($text -match "Hotkey|System Event|Button|Quick Launch") {
        return @{
            Category = "Required"
            Recommendation = "KEEP"
            Risk = "Medium"
            Reason = "Likely supports HP function keys, special keys, brightness keys, or hardware buttons."
        }
    }

    if ($text -match "Wolf|Sure Click|Sure Sense|Sure Run|Sure Recover|Client Security") {
        return @{
            Category = "Recommended"
            Recommendation = "KEEP / Review"
            Risk = "Medium"
            Reason = "HP security component. Usually beneficial, but review based on your security setup."
        }
    }

    if ($text -match "Diagnostics|Support Assistant|System Information|BIOS|Firmware") {
        return @{
            Category = "Recommended"
            Recommendation = "KEEP / Optional"
            Risk = "Low"
            Reason = "Useful for diagnostics, firmware, support, or system identification."
        }
    }

    if ($text -match "Insights|Analytics|Touchpoint|Telemetry|App Helper|Notifications") {
        return @{
            Category = "Telemetry"
            Recommendation = "Review / likely disable"
            Risk = "Low"
            Reason = "HP analytics, telemetry, support, or notification component. Usually not required for core hardware function."
        }
    }

    if ($text -match "Audio|LAN|WLAN|Network|Connection Optimizer") {
        return @{
            Category = "Optional"
            Recommendation = "KEEP / Review"
            Risk = "Medium"
            Reason = "May support HP-specific audio, network switching, or connectivity behavior."
        }
    }

    return @{
        Category = "Unknown"
        Recommendation = "Review"
        Risk = "Unknown"
        Reason = "HP-related item detected, but no specific rule matched yet."
    }
}

$findings = @()

# HP Services
Get-ToolkitServices |
    Where-Object {
        "$($_.Name) $($_.DisplayName) $($_.PathName)" -match "HP|Hewlett|Wolf|Sure|Touchpoint|Insights"
    } |
    ForEach-Object {
        $class = Get-HPClassification -Name "$($_.Name) $($_.DisplayName)" -Type "Service"

        $findings += New-ToolkitFinding `
            -Name $_.DisplayName `
            -Type "HP Service" `
            -Vendor "HP" `
            -Category $class.Category `
            -Recommendation $class.Recommendation `
            -Risk $class.Risk `
            -Reason $class.Reason `
            -Source "Windows Service" `
            -Version "" `
            -State $_.State
    }

# HP Installed Software
Get-ToolkitInstalledSoftware |
    Where-Object {
        "$($_.DisplayName) $($_.Publisher)" -match "HP|Hewlett|Wolf|Sure|Touchpoint|Insights"
    } |
    ForEach-Object {
        $name = if ($_.DisplayName) { $_.DisplayName } else { "Unknown HP Software" }
        $class = Get-HPClassification -Name $name -Type "Software"

        $findings += New-ToolkitFinding `
            -Name $name `
            -Type "HP Software" `
            -Vendor "HP" `
            -Category $class.Category `
            -Recommendation $class.Recommendation `
            -Risk $class.Risk `
            -Reason $class.Reason `
            -Source "Installed Software" `
            -Version $_.DisplayVersion `
            -State "Installed"
    }

# HP Drivers
Get-ToolkitDrivers |
    Where-Object {
        "$($_.DeviceName) $($_.Manufacturer) $($_.InfName)" -match "HP|Hewlett|Wolf|Sure"
    } |
    ForEach-Object {
        $name = if ($_.DeviceName) { $_.DeviceName } else { "Unknown HP Driver" }
        $class = Get-HPClassification -Name $name -Type "Driver"

        $findings += New-ToolkitFinding `
            -Name $name `
            -Type "HP Driver" `
            -Vendor "HP" `
            -Category $class.Category `
            -Recommendation $class.Recommendation `
            -Risk $class.Risk `
            -Reason $class.Reason `
            -Source $_.InfName `
            -Version $_.DriverVersion `
            -State "Installed"
    }

# HP Scheduled Tasks
Get-ToolkitScheduledTasks |
    Where-Object {
        "$($_.TaskName) $($_.TaskPath) $($_.Author)" -match "HP|Hewlett|Wolf|Sure|Touchpoint|Insights"
    } |
    ForEach-Object {
        $name = "$($_.TaskPath)$($_.TaskName)"
        $class = Get-HPClassification -Name $name -Type "Scheduled Task"

        $findings += New-ToolkitFinding `
            -Name $name `
            -Type "HP Scheduled Task" `
            -Vendor "HP" `
            -Category $class.Category `
            -Recommendation $class.Recommendation `
            -Risk $class.Risk `
            -Reason $class.Reason `
            -Source "Task Scheduler" `
            -Version "" `
            -State $_.State
    }

Save-CsvReport `
    -Name "HP_Analyzer" `
    -Data $findings

Write-Success "HP Analyzer complete."
Write-Host "HP items found: $($findings.Count)"
Write-Host "Report saved to: $Global:ToolkitRunPath\HP_Analyzer.csv"
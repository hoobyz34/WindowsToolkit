$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force

Write-Section "Service Analyzer"

function Get-ServiceCategory {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$PathName
    )

    $text = "$Name $DisplayName $PathName"

    if ($text -match "Defender|WinDefend|Sense|SecurityHealth") { return "Security" }
    if ($text -match "Windows Update|wuauserv|BITS|CryptSvc|TrustedInstaller") { return "Windows Servicing" }
    if ($text -match "HP|Hewlett|Wolf|Sure") { return "HP / OEM" }
    if ($text -match "Intel|DPTF|Dynamic Tuning|MEI|Management Engine") { return "Intel" }
    if ($text -match "NVIDIA|NVDisplay|NvContainer") { return "NVIDIA" }
    if ($text -match "Xbox|Gaming") { return "Gaming" }
    if ($text -match "Print|Spooler|Fax") { return "Printing" }
    if ($text -match "Bluetooth|Bth") { return "Bluetooth" }
    if ($text -match "Hyper-V|vmcompute|vmmem|WSL|Lxss") { return "Virtualization" }
    if ($text -match "Remote|RDP|TermService") { return "Remote Access" }
    if ($text -match "OneDrive") { return "OneDrive" }

    return "General / Unknown"
}

function Get-ServiceRecommendation {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$Category,
        [string]$StartMode
    )

    $text = "$Name $DisplayName"

    if ($Category -in @("Security", "Windows Servicing")) {
        return @{
            Recommendation = "KEEP"
            Reason = "Core Windows security or servicing component."
        }
    }

    if ($text -match "RpcSs|DcomLaunch|PlugPlay|EventLog|Dhcp|Dnscache|Schedule|Winmgmt|LSM|SamSs") {
        return @{
            Recommendation = "KEEP"
            Reason = "Critical Windows dependency."
        }
    }

    if ($Category -eq "Intel") {
        return @{
            Recommendation = "KEEP"
            Reason = "Likely required for chipset, power, or thermal management."
        }
    }

    if ($Category -eq "NVIDIA") {
        return @{
            Recommendation = "KEEP"
            Reason = "Required or useful for GPU driver functionality."
        }
    }

    if ($Category -eq "HP / OEM") {
        if ($text -match "Analytics|Insights|Telemetry|Touchpoint|App Helper") {
            return @{
                Recommendation = "Review / likely disable"
                Reason = "HP support or analytics component; usually not required for core Windows operation."
            }
        }

        if ($text -match "Hotkey|Audio|LAN|WLAN|System Info|Diagnostics") {
            return @{
                Recommendation = "KEEP / Review"
                Reason = "May support HP function keys, diagnostics, audio, or network behavior."
            }
        }

        return @{
            Recommendation = "Review"
            Reason = "HP/OEM service; needs component-specific review before changing."
        }
    }

    if ($Category -eq "Printing") {
        return @{
            Recommendation = "Optional"
            Reason = "Only needed for printing, scanning, print-to-PDF workflows, or fax."
        }
    }

    if ($Category -eq "Gaming") {
        return @{
            Recommendation = "Optional"
            Reason = "Only needed for Xbox/Game Pass/controller/game integrations."
        }
    }

    if ($Category -eq "Remote Access") {
        return @{
            Recommendation = "Optional / Review"
            Reason = "Only needed if you use remote desktop, remote assistance, or remote management."
        }
    }

    if ($StartMode -eq "Manual") {
        return @{
            Recommendation = "Leave Manual"
            Reason = "Manual services generally do not consume resources unless triggered."
        }
    }

    return @{
        Recommendation = "Review"
        Reason = "No automatic safe recommendation yet."
    }
}

$services = Get-CimInstance Win32_Service | ForEach-Object {
    $category = Get-ServiceCategory -Name $_.Name -DisplayName $_.DisplayName -PathName $_.PathName
    $rec = Get-ServiceRecommendation -Name $_.Name -DisplayName $_.DisplayName -Category $category -StartMode $_.StartMode

    [pscustomobject]@{
        Name           = $_.Name
        DisplayName    = $_.DisplayName
        State          = $_.State
        StartMode      = $_.StartMode
        Category       = $category
        Recommendation = $rec.Recommendation
        Reason         = $rec.Reason
        PathName       = $_.PathName
    }
}

Save-CsvReport "Service_Analyzer" $services

Write-Success "Service Analyzer complete."
Write-Host "Report saved to: $Global:ToolkitRunPath\Service_Analyzer.csv"
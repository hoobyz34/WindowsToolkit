$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Config.psm1" -Force

Write-Section "Startup Analyzer"

$config = Get-ToolkitConfiguration

function Get-VendorGuess {
    param([string]$Text)

    if ($Text -match "OneDrive|Microsoft|Windows") { return "Microsoft" }
    if ($Text -match "HP|Hewlett|Wolf|Sure") { return "HP" }
    if ($Text -match "Intel") { return "Intel" }
    if ($Text -match "NVIDIA|NvContainer") { return "NVIDIA" }
    if ($Text -match "Driver Easy|Easeware") { return "Easeware" }
    if ($Text -match "Adobe") { return "Adobe" }
    if ($Text -match "Google|Chrome") { return "Google" }

    return "Unknown"
}

function Get-StartupRecommendation {
    param(
        [string]$Name,
        [string]$Command,
        [string]$Vendor
    )

    $text = "$Name $Command $Vendor"

    foreach ($keep in $config.preferences.alwaysKeep) {
        if ($text -match [regex]::Escape($keep)) {
            return @{
                Recommendation = "KEEP"
                Risk = "Low"
                Reason = "Matches user profile alwaysKeep preference: $keep"
            }
        }
    }

    foreach ($disable in $config.preferences.likelyDisable) {
        if ($text -match [regex]::Escape($disable)) {
            return @{
                Recommendation = "Review / likely disable"
                Risk = "Low"
                Reason = "Matches user profile likelyDisable preference: $disable"
            }
        }
    }

    if ($Vendor -eq "HP") {
        return @{
            Recommendation = "Review"
            Risk = "Medium"
            Reason = "HP startup component; review before disabling."
        }
    }

    if ($Vendor -in @("Intel", "NVIDIA")) {
        return @{
            Recommendation = "KEEP / Review"
            Risk = "Medium"
            Reason = "Hardware vendor component; may support drivers or control panels."
        }
    }

    return @{
        Recommendation = "Review"
        Risk = "Unknown"
        Reason = "No profile or rule match yet."
    }
}

$items = @()

# Registry startup entries
$runKeys = @(
    @{ Source = "HKCU Run"; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" },
    @{ Source = "HKLM Run"; Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" },
    @{ Source = "HKLM WOW6432 Run"; Path = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" },
    @{ Source = "HKCU RunOnce"; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" },
    @{ Source = "HKLM RunOnce"; Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" }
)

foreach ($key in $runKeys) {
    if (Test-Path $key.Path) {
        $props = Get-ItemProperty $key.Path
        $props.PSObject.Properties |
            Where-Object { $_.Name -notmatch "^PS" } |
            ForEach-Object {
                $vendor = Get-VendorGuess "$($_.Name) $($_.Value)"
                $rec = Get-StartupRecommendation -Name $_.Name -Command $_.Value -Vendor $vendor

                $items += [pscustomobject]@{
                    Name           = $_.Name
                    Source         = $key.Source
                    Vendor         = $vendor
                    Command        = $_.Value
                    Recommendation = $rec.Recommendation
                    Risk           = $rec.Risk
                    Reason         = $rec.Reason
                }
            }
    }
}

# Startup folders
$startupFolders = @(
    @{ Source = "Current User Startup Folder"; Path = [Environment]::GetFolderPath("Startup") },
    @{ Source = "All Users Startup Folder"; Path = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" }
)

foreach ($folder in $startupFolders) {
    if (Test-Path $folder.Path) {
        Get-ChildItem $folder.Path -ErrorAction SilentlyContinue | ForEach-Object {
            $vendor = Get-VendorGuess "$($_.Name) $($_.FullName)"
            $rec = Get-StartupRecommendation -Name $_.Name -Command $_.FullName -Vendor $vendor

            $items += [pscustomobject]@{
                Name           = $_.Name
                Source         = $folder.Source
                Vendor         = $vendor
                Command        = $_.FullName
                Recommendation = $rec.Recommendation
                Risk           = $rec.Risk
                Reason         = $rec.Reason
            }
        }
    }
}

# Scheduled tasks with startup/logon triggers
Get-ScheduledTask | ForEach-Object {
    $task = $_
    $triggerText = ($task.Triggers | Out-String)

    if ($triggerText -match "AtLogOn|AtStartup|Logon|Startup") {
        $name = "$($task.TaskPath)$($task.TaskName)"
        $vendor = Get-VendorGuess "$name $($task.Author)"
        $rec = Get-StartupRecommendation -Name $name -Command $task.Author -Vendor $vendor

        $items += [pscustomobject]@{
            Name           = $name
            Source         = "Scheduled Task"
            Vendor         = $vendor
            Command        = $task.Author
            Recommendation = $rec.Recommendation
            Risk           = $rec.Risk
            Reason         = $rec.Reason
        }
    }
}

# Automatic services
Get-CimInstance Win32_Service |
    Where-Object { $_.StartMode -eq "Auto" } |
    ForEach-Object {
        $vendor = Get-VendorGuess "$($_.Name) $($_.DisplayName) $($_.PathName)"
        $rec = Get-StartupRecommendation -Name $_.DisplayName -Command $_.PathName -Vendor $vendor

        $items += [pscustomobject]@{
            Name           = $_.DisplayName
            Source         = "Automatic Service"
            Vendor         = $vendor
            Command        = $_.PathName
            Recommendation = $rec.Recommendation
            Risk           = $rec.Risk
            Reason         = $rec.Reason
        }
    }

Save-CsvReport "Startup_Analyzer" $items

Write-Success "Startup Analyzer complete."
Write-Host "Report saved to: $Global:ToolkitRunPath\Startup_Analyzer.csv"
<#
.SYNOPSIS
    Windows discovery functions for WindowsToolkit.
#>

function Get-ToolkitServices {
    Get-CimInstance Win32_Service
}

function Get-ToolkitStartupCommands {
    Get-CimInstance Win32_StartupCommand
}

function Get-ToolkitScheduledTasks {
    Get-ScheduledTask
}

function Get-ToolkitInstalledSoftware {
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            Get-ItemProperty $path -ErrorAction SilentlyContinue
        }
    }
}

function Get-ToolkitDrivers {
    Get-CimInstance Win32_PnPSignedDriver
}
function Get-ToolkitWindowsFeatures {
    [CmdletBinding()]
    param()

    $output = & dism.exe /Online /Get-Features /Format:Table /English 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Windows feature discovery failed. DISM exited with code $LASTEXITCODE."
    }

    foreach ($line in $output) {
        if ($line -match '^\s*(?<FeatureName>[^|]+?)\s*\|\s*(?<State>Enabled|Disabled|Enable Pending|Disable Pending|Disabled with Payload Removed)\s*$') {
            [PSCustomObject]@{
                FeatureName = $matches.FeatureName.Trim()
                State       = $matches.State.Trim()
            }
        }
    }
}
function Get-ToolkitAppxPackages {
    Get-AppxPackage |
        Sort-Object Name
}
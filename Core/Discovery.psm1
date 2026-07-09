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
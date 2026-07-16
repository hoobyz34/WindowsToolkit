<#
.SYNOPSIS
    Windows discovery functions for WindowsToolkit.
#>

function ConvertTo-ToolkitServiceStartupType {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$StartMode
    )

    switch ($StartMode) {
        "Auto" { return "Automatic" }
        "Automatic" { return "Automatic" }
        "Manual" { return "Manual" }
        "Disabled" { return "Disabled" }
        default { return $StartMode }
    }
}

function Get-ToolkitServiceRecoveryConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServiceName
    )

    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"

    try {
        $configuration = Get-ItemProperty `
            -LiteralPath $path `
            -ErrorAction Stop
        $failureActionsProperty = $configuration.PSObject.Properties["FailureActions"]
        $nonCrashProperty = $configuration.PSObject.Properties[
            "FailureActionsOnNonCrashFailures"
        ]
        $failureActions = if (
            $null -ne $failureActionsProperty -and
            $null -ne $failureActionsProperty.Value
        ) {
            [Convert]::ToBase64String([byte[]]$failureActionsProperty.Value)
        }
        else {
            ""
        }

        return [ordered]@{
            FailureActionsPresent = $null -ne $failureActionsProperty
            FailureActionsBase64 = $failureActions
            FailureActionsOnNonCrashFailures = if ($null -ne $nonCrashProperty) {
                [string]$nonCrashProperty.Value
            }
            else {
                ""
            }
        } | ConvertTo-Json -Compress
    }
    catch {
        return ""
    }
}

function Get-ToolkitServiceInventoryRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][object]$CimService
    )

    if ($null -eq $CimService) {
        $matches = @(
            Get-CimInstance Win32_Service |
                Where-Object {
                    [string]::Equals(
                        [string]$_.Name,
                        $Name,
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                }
        )

        if ($matches.Count -ne 1) {
            throw "Expected exactly one service named '$Name'; found $($matches.Count)."
        }

        $CimService = $matches[0]
    }

    $serviceController = Get-Service `
        -Name ([string]$CimService.Name) `
        -ErrorAction Stop
    $dependencies = @(
        $serviceController.ServicesDependedOn |
            ForEach-Object { [string]$_.Name } |
            Sort-Object
    )

    return [PSCustomObject]@{
        Name                  = [string]$CimService.Name
        DisplayName           = [string]$CimService.DisplayName
        PathName              = [string]$CimService.PathName
        State                 = [string]$CimService.State
        StartMode             = [string]$CimService.StartMode
        StartupType           = ConvertTo-ToolkitServiceStartupType `
            -StartMode ([string]$serviceController.StartType)
        Dependencies          = ConvertTo-Json `
            -InputObject $dependencies `
            -Compress
        RecoveryConfiguration = Get-ToolkitServiceRecoveryConfiguration `
            -ServiceName ([string]$CimService.Name)
    }
}

function Get-ToolkitServices {
    foreach ($service in Get-CimInstance Win32_Service) {
        Get-ToolkitServiceInventoryRecord `
            -Name ([string]$service.Name) `
            -CimService $service
    }
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

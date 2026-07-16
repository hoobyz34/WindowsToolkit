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

    if (
        [string]::IsNullOrWhiteSpace($ServiceName) -or
        [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($ServiceName) -or
        $ServiceName -match "[\\/\x00-\x1f]" -or
        $ServiceName.Contains("..")
    ) {
        throw "Service name must be a safe literal registry-key leaf."
    }

    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"

    try {
        $configuration = Get-ItemProperty `
            -LiteralPath $path `
            -ErrorAction Stop
        $failureActionsProperty = $configuration.PSObject.Properties["FailureActions"]
        $nonCrashProperty = $configuration.PSObject.Properties[
            "FailureActionsOnNonCrashFailures"
        ]
        $failureCommandProperty = $configuration.PSObject.Properties[
            "FailureCommand"
        ]
        $rebootMessageProperty = $configuration.PSObject.Properties[
            "RebootMessage"
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
            FailureActionsOnNonCrashFailuresPresent = $null -ne $nonCrashProperty
            FailureActionsOnNonCrashFailures = if ($null -ne $nonCrashProperty) {
                [string]$nonCrashProperty.Value
            }
            else {
                ""
            }
            FailureCommandPresent = $null -ne $failureCommandProperty
            FailureCommand = if ($null -ne $failureCommandProperty) {
                [string]$failureCommandProperty.Value
            }
            else {
                ""
            }
            RebootMessagePresent = $null -ne $rebootMessageProperty
            RebootMessage = if ($null -ne $rebootMessageProperty) {
                [string]$rebootMessageProperty.Value
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

function Get-ToolkitServiceDelayedAutoStartConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServiceName
    )

    if (
        [string]::IsNullOrWhiteSpace($ServiceName) -or
        [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($ServiceName) -or
        $ServiceName -match "[\\/\x00-\x1f]" -or
        $ServiceName.Contains("..")
    ) {
        throw "Service name must be a safe literal registry-key leaf."
    }

    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"

    try {
        $configuration = Get-ItemProperty `
            -LiteralPath $path `
            -ErrorAction Stop
        $property = $configuration.PSObject.Properties["DelayedAutoStart"]

        return [ordered]@{
            Present = $null -ne $property
            Value = if ($null -ne $property) {
                [string]$property.Value
            }
            else {
                "0"
            }
        } | ConvertTo-Json -Compress
    }
    catch {
        return ""
    }
}

function Get-ToolkitServiceExecutableIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PathName
    )

    $trimmedPath = $PathName.Trim()
    $executablePath = if ($trimmedPath.StartsWith('"')) {
        $closingQuote = $trimmedPath.IndexOf('"', 1)
        if ($closingQuote -le 1) {
            throw "The service executable path contains an unterminated quote."
        }

        $trimmedPath.Substring(1, $closingQuote - 1)
    }
    else {
        $executableEnd = $trimmedPath.IndexOf(
            ".exe",
            [System.StringComparison]::OrdinalIgnoreCase
        )
        if ($executableEnd -lt 0) {
            throw "The service executable path does not identify an executable."
        }

        $trimmedPath.Substring(0, $executableEnd + 4)
    }

    $item = Get-Item -LiteralPath $executablePath -ErrorAction Stop
    if ($item.PSIsContainer) {
        throw "The service executable path resolves to a directory."
    }

    $signature = Get-AuthenticodeSignature `
        -LiteralPath $item.FullName `
        -ErrorAction Stop

    return [PSCustomObject]@{
        ExecutablePath            = [string]$item.FullName
        ExecutableCompany         = [string]$item.VersionInfo.CompanyName
        ExecutableProduct         = [string]$item.VersionInfo.ProductName
        ExecutableSignatureStatus = [string]$signature.Status
        ExecutableSignerSubject   = if ($null -ne $signature.SignerCertificate) {
            [string]$signature.SignerCertificate.Subject
        }
        else {
            ""
        }
    }
}

function Get-ToolkitServiceInventoryRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][object]$CimService,
        [switch]$IncludeExecutableIdentity
    )

    if (
        [string]::IsNullOrWhiteSpace($Name) -or
        [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name) -or
        $Name -match "[\\/\x00-\x1f]" -or
        $Name.Contains("..")
    ) {
        throw "Service name must be a safe literal identity."
    }

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
    elseif (-not [string]::Equals(
        [string]$CimService.Name,
        $Name,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "The supplied service inventory record does not match '$Name'."
    }

    $serviceMatches = @(
        Get-Service `
            -Name ([string]$CimService.Name) `
            -ErrorAction Stop
    )
    if (
        $serviceMatches.Count -ne 1 -or
        -not [string]::Equals(
            [string]$serviceMatches[0].Name,
            [string]$CimService.Name,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw "The service controller identity does not exactly match '$Name'."
    }

    $serviceController = $serviceMatches[0]
    $dependencies = @(
        $serviceController.ServicesDependedOn |
            ForEach-Object { [string]$_.Name } |
            Sort-Object
    )
    $dependentServices = @(
        $serviceController.DependentServices |
            ForEach-Object { [string]$_.Name } |
            Sort-Object
    )
    $executableIdentity = if ($IncludeExecutableIdentity) {
        try {
            Get-ToolkitServiceExecutableIdentity `
                -PathName ([string]$CimService.PathName)
        }
        catch {
            [PSCustomObject]@{
                ExecutablePath            = ""
                ExecutableCompany         = ""
                ExecutableProduct         = ""
                ExecutableSignatureStatus = ""
                ExecutableSignerSubject   = ""
            }
        }
    }
    else {
        [PSCustomObject]@{
            ExecutablePath            = ""
            ExecutableCompany         = ""
            ExecutableProduct         = ""
            ExecutableSignatureStatus = ""
            ExecutableSignerSubject   = ""
        }
    }

    return [PSCustomObject]@{
        Name                  = [string]$CimService.Name
        DisplayName           = [string]$CimService.DisplayName
        PathName              = [string]$CimService.PathName
        State                 = [string]$CimService.State
        StartMode             = [string]$CimService.StartMode
        StartName             = [string]$CimService.StartName
        ServiceType           = [string]$CimService.ServiceType
        StartupType           = ConvertTo-ToolkitServiceStartupType `
            -StartMode ([string]$serviceController.StartType)
        DelayedAutoStartConfiguration = Get-ToolkitServiceDelayedAutoStartConfiguration `
            -ServiceName ([string]$CimService.Name)
        Dependencies          = ConvertTo-Json `
            -InputObject $dependencies `
            -Compress
        DependentServices     = ConvertTo-Json `
            -InputObject $dependentServices `
            -Compress
        ExecutablePath        = [string]$executableIdentity.ExecutablePath
        ExecutableCompany     = [string]$executableIdentity.ExecutableCompany
        ExecutableProduct     = [string]$executableIdentity.ExecutableProduct
        ExecutableSignatureStatus = [string]$executableIdentity.ExecutableSignatureStatus
        ExecutableSignerSubject = [string]$executableIdentity.ExecutableSignerSubject
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

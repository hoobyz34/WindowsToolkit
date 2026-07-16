Import-Module (Join-Path $PSScriptRoot "Models.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Utility.psm1") -Force

function Get-ToolkitOptimizationExecutorContract {
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        PolicyId                   = "disable-hp-scheduled-task"
        ActionId                   = "review-likely-disable"
        OperationType              = "ScheduledTaskStateChange"
        SourceTypes                = @("Scheduled Task", "ScheduledTask")
        Vendor                     = "HP"
        ReportFile                 = "ScheduledTasks_Report.csv"
        AllowedCurrentStates       = @("Ready", "Disabled")
        ExecutorId                 = "DisableScheduledTask"
        TargetState                = "Disabled"
        MutatingCommands           = @("Disable-ScheduledTask")
        RollbackOperationType      = "EnableScheduledTask"
        RollbackTargetState        = "Enabled"
        TaskPathPrefix             = "\HP\"
        TaskNamePatterns           = @(
            "HP Insights",
            "HP Analytics",
            "HP Touchpoint",
            "Telemetry"
        )
        TaskAuthorPatterns         = @(
            "HP",
            "Hewlett-Packard"
        )
        PermanentProtectedPatterns = @(
            "Microsoft Defender",
            "Windows Update",
            "Microsoft Store",
            "Windows Hello",
            "OneDrive",
            "Driver Easy"
        )
    }
}

function Get-ToolkitOptimizationServiceExecutorContract {
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        PolicyId              = "disable-hp-insights-analytics-service"
        ActionId              = "review-likely-disable"
        OperationType         = "ServiceStateChange"
        SourceTypes           = @("Service")
        Vendor                = "HP"
        ReportFile            = "Service_Analyzer.csv"
        AllowedCurrentStates  = @("Running")
        AllowedStartupTypes   = @("Automatic")
        ServiceName           = "HpTouchpointAnalyticsService"
        ServiceDisplayName    = "HP Insights Analytics"
        RequiredDependencies  = @("ProfSvc", "rpcss")
        AllowedDependentServices = @()
        ServiceStartName      = "LocalSystem"
        ServiceType           = "Own Process"
        DelayedAutoStartPresent = $false
        DelayedAutoStartValue = "0"
        RecoveryFailureActionsBase64 = "gFEBAAEAAAABAAAAAwAAABQAAAABAAAAMHUAAAEAAABg6gAAAQAAAJBfAQA="
        ExecutableFileName    = "TouchpointAnalyticsClientService.exe"
        ExecutablePathMarker  = "\System32\DriverStore\FileRepository\hpanalyticscomp.inf_"
        ExecutablePathSuffix  = "\x64\TouchpointAnalyticsClientService.exe"
        ExecutableCompany     = "HP Inc."
        ExecutableProduct     = "HP Insights Analytics"
        ExecutableSignatureStatus = "Valid"
        ExecutableSignerSubjectPattern = "Microsoft Windows Hardware Compatibility Publisher"
        ExecutorId            = "DisableService"
        TargetState           = "Stopped"
        TargetStartupType     = "Disabled"
        MutatingCommands      = @("Stop-Service", "Set-Service")
        RollbackOperationType = "RestoreServiceConfiguration"
        RollbackTargetState   = "CapturedBeforeState"
        RollbackMutatingCommands = @(
            "Set-Service",
            "Start-Service",
            "New-ItemProperty",
            "Remove-ItemProperty"
        )
    }
}

function Test-ToolkitOptimizationTextEquals {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Left,
        [AllowNull()][object]$Right
    )

    return [string]::Equals(
        [string]$Left,
        [string]$Right,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Test-ToolkitOptimizationCollectionContains {
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$Values,
        [AllowNull()][object]$Expected
    )

    return @(
        @($Values) |
            Where-Object {
                Test-ToolkitOptimizationTextEquals -Left $_ -Right $Expected
            }
    ).Count -gt 0
}

function Test-ToolkitOptimizationCollectionSetEquals {
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$Left,
        [AllowNull()][object[]]$Right
    )

    $leftValues = @($Left)
    $rightValues = @($Right)
    if ($leftValues.Count -ne $rightValues.Count) {
        return $false
    }

    foreach ($value in $rightValues) {
        if (
            -not (Test-ToolkitOptimizationCollectionContains `
                -Values $leftValues `
                -Expected $value)
        ) {
            return $false
        }
    }

    return $true
}

function Get-ToolkitOptimizationConfiguredExecutionPatterns {
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$ConfiguredPatterns,
        [Parameter(Mandatory)][string[]]$MaximumPatterns
    )

    return @(
        foreach ($maximumPattern in $MaximumPatterns) {
            if (
                Test-ToolkitOptimizationCollectionContains `
                    -Values $ConfiguredPatterns `
                    -Expected $maximumPattern
            ) {
                $maximumPattern
            }
        }
    )
}

function Test-ToolkitPermanentOptimizationProtection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry
    )

    $contract = Get-ToolkitOptimizationExecutorContract
    $searchText = @(
        Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFinding"
        Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceName"
        Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Source"
        Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Category"
    ) -join " "
    $category = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Category"
    $risk = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Risk"
    $source = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Source"

    if (
        (Test-ToolkitOptimizationTextEquals $category "Required") -or
        (Test-ToolkitOptimizationTextEquals $risk "Critical") -or
        $source.StartsWith(
            "\Microsoft\",
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return $true
    }

    foreach ($protectedPattern in $contract.PermanentProtectedPatterns) {
        if (
            $searchText.IndexOf(
                $protectedPattern,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -ge 0
        ) {
            return $true
        }
    }

    return $false
}

function Test-ToolkitOptimizationLiteralTaskIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskName,
        [Parameter(Mandatory)][string]$TaskPath
    )

    if (
        [string]::IsNullOrWhiteSpace($TaskName) -or
        [string]::IsNullOrWhiteSpace($TaskPath) -or
        [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($TaskName) -or
        [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($TaskPath) -or
        $TaskName -match "[\\/\x00-\x1f]" -or
        $TaskPath -match "[\x00-\x1f]" -or
        $TaskPath.Contains("..") -or
        -not $TaskPath.EndsWith("\", [System.StringComparison]::Ordinal)
    ) {
        return $false
    }

    return $true
}

function Test-ToolkitOptimizationLiteralServiceIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServiceName
    )

    return (
        -not [string]::IsNullOrWhiteSpace($ServiceName) -and
        -not [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters(
            $ServiceName
        ) -and
        $ServiceName -notmatch "[\\/\x00-\x1f]" -and
        -not $ServiceName.Contains("..")
    )
}

function ConvertFrom-ToolkitOptimizationStringArray {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$Json
    )

    if (
        [string]::IsNullOrWhiteSpace($Json) -or
        -not $Json.TrimStart().StartsWith("[") -or
        -not $Json.TrimEnd().EndsWith("]")
    ) {
        return $null
    }

    try {
        $values = @($Json | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        return $null
    }

    foreach ($value in $values) {
        if (
            $null -eq $value -or
            [string]::IsNullOrWhiteSpace([string]$value) -or
            [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters(
                [string]$value
            ) -or
            [string]$value -match "[\\/\x00-\x1f]" -or
            [string]$value -like "*..*"
        ) {
            return $null
        }
    }

    return ,$values
}

function Test-ToolkitOptimizationRecoveryConfiguration {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$Json,
        [string]$ExpectedFailureActionsBase64 = (
            Get-ToolkitOptimizationServiceExecutorContract
        ).RecoveryFailureActionsBase64
    )

    try {
        $configuration = $Json | ConvertFrom-Json -ErrorAction Stop
        $requiredProperties = @(
            "FailureActionsPresent",
            "FailureActionsBase64",
            "FailureActionsOnNonCrashFailuresPresent",
            "FailureActionsOnNonCrashFailures",
            "FailureCommandPresent",
            "FailureCommand",
            "RebootMessagePresent",
            "RebootMessage"
        )
        foreach ($propertyName in $requiredProperties) {
            if ($null -eq $configuration.PSObject.Properties[$propertyName]) {
                return $false
            }
        }

        foreach ($booleanProperty in @(
            "FailureActionsPresent",
            "FailureActionsOnNonCrashFailuresPresent",
            "FailureCommandPresent",
            "RebootMessagePresent"
        )) {
            if ($configuration.$booleanProperty -isnot [bool]) {
                return $false
            }
        }

        if (
            -not $configuration.FailureActionsPresent -or
            [string]::IsNullOrWhiteSpace([string]$configuration.FailureActionsBase64) -or
            [string]$configuration.FailureActionsBase64 -cne
                $ExpectedFailureActionsBase64 -or
            $configuration.FailureActionsOnNonCrashFailuresPresent -or
            -not [string]::IsNullOrEmpty(
                [string]$configuration.FailureActionsOnNonCrashFailures
            ) -or
            $configuration.FailureCommandPresent -or
            -not [string]::IsNullOrEmpty([string]$configuration.FailureCommand) -or
            $configuration.RebootMessagePresent -or
            -not [string]::IsNullOrEmpty([string]$configuration.RebootMessage)
        ) {
            return $false
        }

        try {
            $failureActions = [Convert]::FromBase64String(
                [string]$configuration.FailureActionsBase64
            )
        }
        catch {
            return $false
        }
        if ($failureActions.Count -eq 0 -or $failureActions.Count -gt 4096) {
            return $false
        }

        return $true
    }
    catch {
        return $false
    }
}

function ConvertTo-ToolkitOptimizationSwitchBoolean {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [bool]) {
        return [bool]$Value
    }

    if ($Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]) {
        if ([int64]$Value -eq 0) {
            return $false
        }
        if ([int64]$Value -eq 1) {
            return $true
        }

        throw "The switch value must be zero or one."
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "The switch value is empty."
    }

    switch ($text.Trim().ToLowerInvariant()) {
        "0" { return $false }
        "false" { return $false }
        "null" { return $false }
        "1" { return $true }
        "true" { return $true }
        default { throw "The switch value is not a recognized boolean representation." }
    }
}

function ConvertTo-ToolkitOptimizationDelayedAutoStartConfiguration {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Configuration
    )

    $parsed = $Configuration
    if ($Configuration -is [string]) {
        if ([string]::IsNullOrWhiteSpace([string]$Configuration)) {
            throw "The delayed-start configuration is empty."
        }

        $parsed = [string]$Configuration |
            ConvertFrom-Json -ErrorAction Stop
    }

    $presentProperty = if ($null -eq $parsed) {
        $null
    }
    else {
        $parsed.PSObject.Properties["Present"]
    }
    $valueProperty = if ($null -eq $parsed) {
        $null
    }
    else {
        $parsed.PSObject.Properties["Value"]
    }

    if ($null -ne $presentProperty -or $null -ne $valueProperty) {
        if ($null -eq $presentProperty -or $null -eq $valueProperty) {
            throw "The delayed-start configuration must contain Present and Value."
        }

        $propertyNames = @($parsed.PSObject.Properties.Name)
        if (
            $propertyNames.Count -ne 2 -or
            "Present" -notin $propertyNames -or
            "Value" -notin $propertyNames
        ) {
            throw "The delayed-start configuration contains unexpected fields."
        }

        $present = ConvertTo-ToolkitOptimizationSwitchBoolean `
            -Value $presentProperty.Value
        $enabledValue = ConvertTo-ToolkitOptimizationSwitchBoolean `
            -Value $valueProperty.Value
        if (-not $present -and $enabledValue) {
            throw "An absent delayed-start value cannot be enabled."
        }

        $enabled = $present -and $enabledValue
    }
    else {
        $enabled = ConvertTo-ToolkitOptimizationSwitchBoolean -Value $parsed
    }

    return [ordered]@{
        Present = [bool]$enabled
        Value   = if ($enabled) { "1" } else { "0" }
    } | ConvertTo-Json -Compress
}

function Test-ToolkitOptimizationDelayedAutoStartConfiguration {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$Json,
        [bool]$ExpectedPresent = (
            Get-ToolkitOptimizationServiceExecutorContract
        ).DelayedAutoStartPresent,
        [string]$ExpectedValue = (
            Get-ToolkitOptimizationServiceExecutorContract
        ).DelayedAutoStartValue
    )

    try {
        $actual = ConvertTo-ToolkitOptimizationDelayedAutoStartConfiguration `
            -Configuration $Json
        $expected = ConvertTo-ToolkitOptimizationDelayedAutoStartConfiguration `
            -Configuration ([PSCustomObject]@{
                Present = $ExpectedPresent
                Value   = $ExpectedValue
            })

        return $actual -ceq $expected
    }
    catch {
        return $false
    }
}

function Get-ToolkitOptimizationExecutionPolicyMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][string]$OperationType,
        [Parameter(Mandatory)][object]$Rules
    )

    $contract = Get-ToolkitOptimizationExecutorContract
    $actionId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ActionId"
    $sourceType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType"
    $vendor = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Vendor"
    $reportFile = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ReportFile"
    $currentState = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "CurrentState"

    foreach ($policy in @($Rules.executionPolicies)) {
        $namePatterns = Get-ToolkitOptimizationConfiguredExecutionPatterns `
            -ConfiguredPatterns @($policy.allowedTaskNamePatterns) `
            -MaximumPatterns $contract.TaskNamePatterns
        $authorPatterns = Get-ToolkitOptimizationConfiguredExecutionPatterns `
            -ConfiguredPatterns @($policy.allowedTaskAuthorPatterns) `
            -MaximumPatterns $contract.TaskAuthorPatterns
        $policyContractValid = (
            (Test-ToolkitOptimizationTextEquals $policy.id $contract.PolicyId) -and
            (Test-ToolkitOptimizationTextEquals $policy.actionId $contract.ActionId) -and
            (Test-ToolkitOptimizationTextEquals $policy.operationType $contract.OperationType) -and
            (Test-ToolkitOptimizationTextEquals $policy.executorId $contract.ExecutorId) -and
            (Test-ToolkitOptimizationTextEquals $policy.targetState $contract.TargetState) -and
            (Test-ToolkitOptimizationCollectionSetEquals $policy.mutatingCommands $contract.MutatingCommands) -and
            (Test-ToolkitOptimizationTextEquals $policy.rollbackOperationType $contract.RollbackOperationType) -and
            (Test-ToolkitOptimizationTextEquals $policy.rollbackTargetState $contract.RollbackTargetState) -and
            (Test-ToolkitOptimizationCollectionContains $policy.allowedTaskPathPrefixes $contract.TaskPathPrefix) -and
            $namePatterns.Count -gt 0 -and
            $authorPatterns.Count -gt 0
        )
        $planMatchesPolicy = (
            (Test-ToolkitOptimizationTextEquals $actionId $contract.ActionId) -and
            (Test-ToolkitOptimizationTextEquals $OperationType $contract.OperationType) -and
            (Test-ToolkitOptimizationCollectionContains $contract.SourceTypes $sourceType) -and
            (Test-ToolkitOptimizationCollectionContains $policy.sourceTypes $sourceType) -and
            (Test-ToolkitOptimizationTextEquals $vendor $contract.Vendor) -and
            (Test-ToolkitOptimizationCollectionContains $policy.allowedVendors $vendor) -and
            (Test-ToolkitOptimizationTextEquals $reportFile $contract.ReportFile) -and
            (Test-ToolkitOptimizationCollectionContains $policy.allowedReportFiles $reportFile) -and
            (Test-ToolkitOptimizationCollectionContains $contract.AllowedCurrentStates $currentState) -and
            (Test-ToolkitOptimizationCollectionContains $policy.allowedCurrentStates $currentState)
        )

        if ($policyContractValid -and $planMatchesPolicy) {
            return [PSCustomObject]@{
                Id                    = $contract.PolicyId
                ActionId              = $contract.ActionId
                OperationType         = $contract.OperationType
                ExecutorId            = $contract.ExecutorId
                TargetState           = $contract.TargetState
                RollbackOperationType = $contract.RollbackOperationType
                RollbackTargetState   = $contract.RollbackTargetState
                TaskPathPrefix        = $contract.TaskPathPrefix
                TaskNamePatterns      = $namePatterns
                TaskAuthorPatterns    = $authorPatterns
            }
        }
    }

    $serviceContract = Get-ToolkitOptimizationServiceExecutorContract
    $serviceName = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ServiceName"
    $serviceDisplayName = Get-ToolkitFindingPropertyValue `
        -Finding $PlanEntry `
        -Name "ServiceDisplayName"
    $startupType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "StartupType"
    $dependencies = ConvertFrom-ToolkitOptimizationStringArray `
        -Json (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Dependencies")
    $dependentServices = ConvertFrom-ToolkitOptimizationStringArray `
        -Json (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "DependentServices")
    $serviceStartName = Get-ToolkitFindingPropertyValue `
        -Finding $PlanEntry `
        -Name "ServiceStartName"
    $serviceType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ServiceType"
    $executablePath = Get-ToolkitFindingPropertyValue `
        -Finding $PlanEntry `
        -Name "ExecutablePath"
    $executableCompany = Get-ToolkitFindingPropertyValue `
        -Finding $PlanEntry `
        -Name "ExecutableCompany"
    $executableProduct = Get-ToolkitFindingPropertyValue `
        -Finding $PlanEntry `
        -Name "ExecutableProduct"
    $executableSignatureStatus = Get-ToolkitFindingPropertyValue `
        -Finding $PlanEntry `
        -Name "ExecutableSignatureStatus"
    $executableSignerSubject = Get-ToolkitFindingPropertyValue `
        -Finding $PlanEntry `
        -Name "ExecutableSignerSubject"

    foreach ($policy in @($Rules.executionPolicies)) {
        $policyContractValid = (
            (Test-ToolkitOptimizationTextEquals $policy.id $serviceContract.PolicyId) -and
            (Test-ToolkitOptimizationTextEquals $policy.actionId $serviceContract.ActionId) -and
            (Test-ToolkitOptimizationTextEquals $policy.operationType $serviceContract.OperationType) -and
            (Test-ToolkitOptimizationTextEquals $policy.executorId $serviceContract.ExecutorId) -and
            (Test-ToolkitOptimizationTextEquals $policy.targetState $serviceContract.TargetState) -and
            (Test-ToolkitOptimizationTextEquals $policy.targetStartupType $serviceContract.TargetStartupType) -and
            (Test-ToolkitOptimizationCollectionSetEquals $policy.mutatingCommands $serviceContract.MutatingCommands) -and
            (Test-ToolkitOptimizationTextEquals $policy.rollbackOperationType $serviceContract.RollbackOperationType) -and
            (Test-ToolkitOptimizationTextEquals $policy.rollbackTargetState $serviceContract.RollbackTargetState) -and
            (Test-ToolkitOptimizationTextEquals $policy.serviceName $serviceContract.ServiceName) -and
            (Test-ToolkitOptimizationTextEquals $policy.serviceDisplayName $serviceContract.ServiceDisplayName) -and
            (Test-ToolkitOptimizationCollectionSetEquals $policy.requiredDependencies $serviceContract.RequiredDependencies) -and
            (Test-ToolkitOptimizationCollectionSetEquals $policy.allowedDependentServices $serviceContract.AllowedDependentServices) -and
            (Test-ToolkitOptimizationTextEquals $policy.serviceStartName $serviceContract.ServiceStartName) -and
            (Test-ToolkitOptimizationTextEquals $policy.serviceType $serviceContract.ServiceType) -and
            [bool]$policy.delayedAutoStartPresent -eq $serviceContract.DelayedAutoStartPresent -and
            (Test-ToolkitOptimizationTextEquals $policy.delayedAutoStartValue $serviceContract.DelayedAutoStartValue) -and
            (Test-ToolkitOptimizationTextEquals $policy.recoveryFailureActionsBase64 $serviceContract.RecoveryFailureActionsBase64) -and
            (Test-ToolkitOptimizationTextEquals $policy.executableFileName $serviceContract.ExecutableFileName) -and
            (Test-ToolkitOptimizationTextEquals $policy.executablePathMarker $serviceContract.ExecutablePathMarker) -and
            (Test-ToolkitOptimizationTextEquals $policy.executablePathSuffix $serviceContract.ExecutablePathSuffix) -and
            (Test-ToolkitOptimizationTextEquals $policy.executableCompany $serviceContract.ExecutableCompany) -and
            (Test-ToolkitOptimizationTextEquals $policy.executableProduct $serviceContract.ExecutableProduct) -and
            (Test-ToolkitOptimizationTextEquals $policy.executableSignatureStatus $serviceContract.ExecutableSignatureStatus) -and
            (Test-ToolkitOptimizationTextEquals $policy.executableSignerSubjectPattern $serviceContract.ExecutableSignerSubjectPattern) -and
            (Test-ToolkitOptimizationCollectionSetEquals $policy.rollbackMutatingCommands $serviceContract.RollbackMutatingCommands)
        )
        $planMatchesPolicy = (
            (Test-ToolkitOptimizationTextEquals $actionId $serviceContract.ActionId) -and
            (Test-ToolkitOptimizationTextEquals $OperationType $serviceContract.OperationType) -and
            (Test-ToolkitOptimizationCollectionContains $serviceContract.SourceTypes $sourceType) -and
            (Test-ToolkitOptimizationCollectionContains $policy.sourceTypes $sourceType) -and
            (Test-ToolkitOptimizationTextEquals $vendor $serviceContract.Vendor) -and
            (Test-ToolkitOptimizationCollectionContains $policy.allowedVendors $vendor) -and
            (Test-ToolkitOptimizationTextEquals $reportFile $serviceContract.ReportFile) -and
            (Test-ToolkitOptimizationCollectionContains $policy.allowedReportFiles $reportFile) -and
            (Test-ToolkitOptimizationCollectionContains $serviceContract.AllowedCurrentStates $currentState) -and
            (Test-ToolkitOptimizationCollectionContains $policy.allowedCurrentStates $currentState) -and
            (Test-ToolkitOptimizationCollectionContains $serviceContract.AllowedStartupTypes $startupType) -and
            (Test-ToolkitOptimizationCollectionContains $policy.allowedStartupTypes $startupType) -and
            (Test-ToolkitOptimizationTextEquals $serviceName $serviceContract.ServiceName) -and
            (Test-ToolkitOptimizationTextEquals $serviceDisplayName $serviceContract.ServiceDisplayName) -and
            (Test-ToolkitOptimizationCollectionSetEquals $dependencies $serviceContract.RequiredDependencies) -and
            (Test-ToolkitOptimizationCollectionSetEquals $dependentServices $serviceContract.AllowedDependentServices) -and
            (Test-ToolkitOptimizationTextEquals $serviceStartName $serviceContract.ServiceStartName) -and
            (Test-ToolkitOptimizationTextEquals $serviceType $serviceContract.ServiceType) -and
            (Test-ToolkitOptimizationTextEquals $executableCompany $serviceContract.ExecutableCompany) -and
            (Test-ToolkitOptimizationTextEquals $executableProduct $serviceContract.ExecutableProduct) -and
            (Test-ToolkitOptimizationTextEquals $executableSignatureStatus $serviceContract.ExecutableSignatureStatus) -and
            $executablePath.EndsWith(
                $serviceContract.ExecutablePathSuffix,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -and
            $executablePath.IndexOf(
                $serviceContract.ExecutablePathMarker,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -ge 0 -and
            (Test-ToolkitOptimizationTextEquals `
                ([System.IO.Path]::GetFileName($executablePath)) `
                $serviceContract.ExecutableFileName) -and
            $executableSignerSubject.IndexOf(
                $serviceContract.ExecutableSignerSubjectPattern,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -ge 0
        )

        if ($policyContractValid -and $planMatchesPolicy) {
            return [PSCustomObject]@{
                Id                    = $serviceContract.PolicyId
                ActionId              = $serviceContract.ActionId
                OperationType         = $serviceContract.OperationType
                ExecutorId            = $serviceContract.ExecutorId
                TargetState           = $serviceContract.TargetState
                TargetStartupType     = $serviceContract.TargetStartupType
                RollbackOperationType = $serviceContract.RollbackOperationType
                RollbackTargetState   = $serviceContract.RollbackTargetState
                ServiceName           = $serviceContract.ServiceName
                ServiceDisplayName    = $serviceContract.ServiceDisplayName
                RequiredDependencies  = $serviceContract.RequiredDependencies
                AllowedDependentServices = $serviceContract.AllowedDependentServices
                ServiceStartName      = $serviceContract.ServiceStartName
                ServiceType           = $serviceContract.ServiceType
                DelayedAutoStartPresent = $serviceContract.DelayedAutoStartPresent
                DelayedAutoStartValue = $serviceContract.DelayedAutoStartValue
                RecoveryFailureActionsBase64 = $serviceContract.RecoveryFailureActionsBase64
                ExecutableFileName    = $serviceContract.ExecutableFileName
                ExecutablePathMarker  = $serviceContract.ExecutablePathMarker
                ExecutablePathSuffix  = $serviceContract.ExecutablePathSuffix
                ExecutableCompany     = $serviceContract.ExecutableCompany
                ExecutableProduct     = $serviceContract.ExecutableProduct
                ExecutableSignatureStatus = $serviceContract.ExecutableSignatureStatus
                ExecutableSignerSubjectPattern = $serviceContract.ExecutableSignerSubjectPattern
            }
        }
    }

    return $null
}

function Test-ToolkitOptimizationExecutorScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    $sourceType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType"
    $sourceName = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceName"
    $source = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Source"
    $sourceFinding = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFinding"
    $category = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Category"
    $recommendation = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Recommendation"
    $expectedFinding = "${sourceType}: $sourceName"

    switch ([string]$ExecutionPolicy.ExecutorId) {
        "DisableScheduledTask" {
            $nameAllowed = @(
                $ExecutionPolicy.TaskNamePatterns |
                    Where-Object {
                        $sourceName.IndexOf(
                            [string]$_,
                            [System.StringComparison]::OrdinalIgnoreCase
                        ) -ge 0
                    }
            ).Count -gt 0

            if (
                -not (Test-ToolkitOptimizationLiteralTaskIdentity `
                    -TaskName $sourceName `
                    -TaskPath $source)
            ) {
                return [PSCustomObject]@{
                    Allowed      = $false
                    DecisionCode = "UnsafeTargetIdentity"
                    Reason       = "The scheduled-task name or path is not a safe literal identity."
                    Remediation  = "Regenerate the plan from a scheduled task with a literal name and path."
                }
            }

            if (
                -not $source.StartsWith(
                    [string]$ExecutionPolicy.TaskPathPrefix,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            ) {
                return [PSCustomObject]@{
                    Allowed      = $false
                    DecisionCode = "OutsideDedicatedTaskScope"
                    Reason       = "The scheduled task is outside the dedicated HP task namespace."
                    Remediation  = "Only HP telemetry tasks under the dedicated \HP\ task path are executable."
                }
            }

            if (
                -not $nameAllowed -or
                -not (Test-ToolkitOptimizationTextEquals $category "Telemetry") -or
                -not (Test-ToolkitOptimizationTextEquals $recommendation "Review / likely disable") -or
                -not (Test-ToolkitOptimizationTextEquals $sourceFinding $expectedFinding)
            ) {
                return [PSCustomObject]@{
                    Allowed      = $false
                    DecisionCode = "TargetScopeMismatch"
                    Reason       = "The plan does not identify an allowlisted HP telemetry scheduled task."
                    Remediation  = "Regenerate the plan from the Scheduled Task analyzer and review the source metadata."
                }
            }

            return [PSCustomObject]@{
                Allowed      = $true
                DecisionCode = "TargetScopeAllowed"
                Reason       = "The target is within the dedicated HP telemetry scheduled-task scope."
                Remediation  = ""
            }
        }

        "DisableService" {
            $serviceName = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ServiceName"
            $serviceDisplayName = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ServiceDisplayName"
            $dependencies = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "Dependencies"
            $recoveryConfiguration = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "RecoveryConfiguration"
            $delayedAutoStartConfiguration = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "DelayedAutoStartConfiguration"
            $servicePath = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ServicePath"
            $serviceStartName = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ServiceStartName"
            $serviceType = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ServiceType"
            $dependentServicesJson = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "DependentServices"
            $dependenciesValues = ConvertFrom-ToolkitOptimizationStringArray `
                -Json $dependencies
            $dependentServicesValues = ConvertFrom-ToolkitOptimizationStringArray `
                -Json $dependentServicesJson
            $executablePath = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ExecutablePath"
            $executableCompany = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ExecutableCompany"
            $executableProduct = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ExecutableProduct"
            $executableSignatureStatus = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ExecutableSignatureStatus"
            $executableSignerSubject = Get-ToolkitFindingPropertyValue `
                -Finding $PlanEntry `
                -Name "ExecutableSignerSubject"

            if (
                -not (Test-ToolkitOptimizationLiteralServiceIdentity $serviceName) -or
                -not (Test-ToolkitOptimizationTextEquals $serviceName $ExecutionPolicy.ServiceName) -or
                -not (Test-ToolkitOptimizationTextEquals $serviceDisplayName $ExecutionPolicy.ServiceDisplayName) -or
                -not (Test-ToolkitOptimizationTextEquals $sourceName $ExecutionPolicy.ServiceDisplayName) -or
                -not (Test-ToolkitOptimizationTextEquals $source "Windows Service") -or
                -not (Test-ToolkitOptimizationTextEquals $category "Telemetry") -or
                -not (Test-ToolkitOptimizationTextEquals $recommendation "Review / likely disable") -or
                -not (Test-ToolkitOptimizationTextEquals $sourceFinding $expectedFinding) -or
                -not (Test-ToolkitOptimizationCollectionSetEquals $dependenciesValues $ExecutionPolicy.RequiredDependencies) -or
                -not (Test-ToolkitOptimizationCollectionSetEquals $dependentServicesValues $ExecutionPolicy.AllowedDependentServices) -or
                -not (Test-ToolkitOptimizationTextEquals $serviceStartName $ExecutionPolicy.ServiceStartName) -or
                -not (Test-ToolkitOptimizationTextEquals $serviceType $ExecutionPolicy.ServiceType) -or
                -not (Test-ToolkitOptimizationDelayedAutoStartConfiguration `
                    -Json $delayedAutoStartConfiguration `
                    -ExpectedPresent $ExecutionPolicy.DelayedAutoStartPresent `
                    -ExpectedValue $ExecutionPolicy.DelayedAutoStartValue) -or
                -not (Test-ToolkitOptimizationRecoveryConfiguration `
                    -Json $recoveryConfiguration `
                    -ExpectedFailureActionsBase64 $ExecutionPolicy.RecoveryFailureActionsBase64) -or
                -not (Test-ToolkitOptimizationTextEquals $executableCompany $ExecutionPolicy.ExecutableCompany) -or
                -not (Test-ToolkitOptimizationTextEquals $executableProduct $ExecutionPolicy.ExecutableProduct) -or
                -not (Test-ToolkitOptimizationTextEquals $executableSignatureStatus $ExecutionPolicy.ExecutableSignatureStatus) -or
                [string]::IsNullOrWhiteSpace($servicePath) -or
                -not (Test-ToolkitOptimizationTextEquals $servicePath $executablePath) -or
                -not $executablePath.EndsWith(
                    $ExecutionPolicy.ExecutablePathSuffix,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -or
                $executablePath.IndexOf(
                    $ExecutionPolicy.ExecutablePathMarker,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -lt 0 -or
                -not (Test-ToolkitOptimizationTextEquals `
                    ([System.IO.Path]::GetFileName($executablePath)) `
                    $ExecutionPolicy.ExecutableFileName) -or
                $executableSignerSubject.IndexOf(
                    $ExecutionPolicy.ExecutableSignerSubjectPattern,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -lt 0
            ) {
                return [PSCustomObject]@{
                    Allowed      = $false
                    DecisionCode = "TargetScopeMismatch"
                    Reason       = "The plan does not contain the exact allowlisted HP Insights Analytics service identity and complete service safety metadata."
                    Remediation  = "Regenerate the Service Analyzer report with service identity, startup, dependency, and recovery data."
                }
            }

            return [PSCustomObject]@{
                Allowed      = $true
                DecisionCode = "TargetScopeAllowed"
                Reason       = "The target is the exact allowlisted HP Insights Analytics service."
                Remediation  = ""
            }
        }

        default {
            return [PSCustomObject]@{
                Allowed      = $false
                DecisionCode = "UnsupportedExecutorScope"
                Reason       = "No executor scope validator exists for this operation."
                Remediation  = "Retain the item; no supported executor capability matches it."
            }
        }
    }
}

function Get-ToolkitOptimizationExecutorEligibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][string]$OperationType,
        [Parameter(Mandatory)][object]$Rules
    )

    if (
        (Test-ToolkitPermanentOptimizationProtection -PlanEntry $PlanEntry) -or
        (Test-ToolkitProtectedFinding -Finding $PlanEntry -Rules $Rules)
    ) {
        return [PSCustomObject]@{
            Allowed            = $false
            DecisionCode       = "ProtectedComponent"
            SafetyPolicyResult = "Blocked - Protected"
            Reason             = "The plan entry matches a permanent protected-component policy."
            Remediation        = "Retain the protected component; executor policy cannot override this block."
            ExecutionPolicy    = $null
        }
    }

    $executionPolicy = Get-ToolkitOptimizationExecutionPolicyMatch `
        -PlanEntry $PlanEntry `
        -OperationType $OperationType `
        -Rules $Rules

    if ($null -eq $executionPolicy) {
        return [PSCustomObject]@{
            Allowed            = $false
            DecisionCode       = "ExecutionPolicyDenied"
            SafetyPolicyResult = "Blocked - Executor Policy"
            Reason             = "No executor policy allowlists this action, source type, operation type, vendor, report source, and current state."
            Remediation        = "Retain the item or regenerate it from the exact analyzer path required by a supported executor policy."
            ExecutionPolicy    = $null
        }
    }

    $atTargetState = Test-ToolkitOptimizationTextEquals `
        (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "CurrentState") `
        $executionPolicy.TargetState
    $atTargetStartupType = (
        (Test-ToolkitOptimizationTextEquals $executionPolicy.ExecutorId "DisableService") -and
        (Test-ToolkitOptimizationTextEquals `
            (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "StartupType") `
            $executionPolicy.TargetStartupType)
    )

    if ($atTargetState -or $atTargetStartupType) {
        return [PSCustomObject]@{
            Allowed            = $false
            DecisionCode       = "AlreadyAtTargetState"
            SafetyPolicyResult = "Blocked - Target State"
            Reason             = "The target is already in the executor target configuration."
            Remediation        = "No action is required; regenerate reports if the plan still proposes this change."
            ExecutionPolicy    = $executionPolicy
        }
    }

    $scope = Test-ToolkitOptimizationExecutorScope `
        -PlanEntry $PlanEntry `
        -ExecutionPolicy $executionPolicy
    if (-not $scope.Allowed) {
        return [PSCustomObject]@{
            Allowed            = $false
            DecisionCode       = $scope.DecisionCode
            SafetyPolicyResult = "Blocked - Executor Scope"
            Reason             = $scope.Reason
            Remediation        = $scope.Remediation
            ExecutionPolicy    = $executionPolicy
        }
    }

    return [PSCustomObject]@{
        Allowed            = $true
        DecisionCode       = "ExecutionPolicyAllowed"
        SafetyPolicyResult = "Allowed"
            Reason             = "The action matches the fixed executor policy and exact dedicated HP target scope."
        Remediation        = ""
        ExecutionPolicy    = $executionPolicy
    }
}

function Get-ToolkitOptimizationActionRules {
    [CmdletBinding()]
    param([string]$Path)

    if (-not $Path) {
        $root = Split-Path -Parent $PSScriptRoot
        $Path = Join-Path $root "Data\OptimizationActions.json"
    }

    if (-not (Test-Path $Path)) {
        throw "Optimization action data file not found: $Path"
    }

    return Get-Content -Path $Path -Raw | ConvertFrom-Json -ErrorAction Stop
}

function Get-ToolkitStableId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Parts
    )

    $canonicalValue = @($Parts | ForEach-Object {
        ([string]$_).Trim().ToLowerInvariant()
    }) -join "|"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonicalValue)
    $hash = [System.Security.Cryptography.SHA256]::Create()

    try {
        $digest = $hash.ComputeHash($bytes)
    }
    finally {
        $hash.Dispose()
    }

    $value = -join ($digest | ForEach-Object { $_.ToString("x2") })
    return "$Prefix-$($value.Substring(0, 16))"
}

function Get-ToolkitFindingPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Finding,
        [Parameter(Mandatory)][string]$Name,
        [string]$Default = ""
    )

    $property = $Finding.PSObject.Properties[$Name]
    if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        return $Default
    }

    return [string]$property.Value
}

function Get-ToolkitOptimizationSourceIdentityParts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Finding
    )

    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($name in @(
        "SourceType",
        "SourceName",
        "Source",
        "SourceVersion",
        "ReportFile"
    )) {
        $findingName = switch ($name) {
            "SourceType" { "Type" }
            "SourceName" { "Name" }
            "SourceVersion" { "Version" }
            default { $name }
        }
        $value = Get-ToolkitFindingPropertyValue `
            -Finding $Finding `
            -Name $name `
            -Default (Get-ToolkitFindingPropertyValue -Finding $Finding -Name $findingName)
        $parts.Add($value)
    }

    $delayedAutoStartConfiguration = Get-ToolkitFindingPropertyValue `
        -Finding $Finding `
        -Name "DelayedAutoStartConfiguration"
    if (-not [string]::IsNullOrWhiteSpace($delayedAutoStartConfiguration)) {
        try {
            $delayedAutoStartConfiguration = `
                ConvertTo-ToolkitOptimizationDelayedAutoStartConfiguration `
                    -Configuration $delayedAutoStartConfiguration
        }
        catch {
            # Preserve invalid input so identity hashing cannot hide metadata drift.
        }
    }

    $serviceValues = @(
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServiceName"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServiceDisplayName"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "StartupType"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServicePath"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServiceStartName"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServiceType"
        $delayedAutoStartConfiguration
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Dependencies"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "DependentServices"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutablePath"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutableCompany"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutableProduct"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutableSignatureStatus"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutableSignerSubject"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "RecoveryConfiguration"
    )
    if (@($serviceValues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
        foreach ($value in $serviceValues) {
            $parts.Add([string]$value)
        }
    }

    return $parts.ToArray()
}

function Test-ToolkitProtectedFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Finding,
        [Parameter(Mandatory)][object]$Rules
    )

    $searchText = @(
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Name"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "SourceName"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "SourceFinding"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Source"
        Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Category"
    ) -join " "

    $category = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Category"
    $risk = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Risk"

    if (
        $category -in @($Rules.protectedCategories) -or
        $risk -in @($Rules.protectedRisks)
    ) {
        return $true
    }

    foreach ($protectedPattern in @($Rules.protectedFindingPatterns)) {
        if ($searchText -match [regex]::Escape([string]$protectedPattern)) {
            return $true
        }
    }

    return $false
}

function Get-ToolkitOptimizationActionRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Finding,
        [Parameter(Mandatory)][object]$Rules
    )

    if (Test-ToolkitProtectedFinding -Finding $Finding -Rules $Rules) {
        return $Rules.protectedAction
    }

    $recommendation = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Recommendation" -Default "Review"
    foreach ($rule in @($Rules.actions)) {
        if ([string]::Equals($recommendation, [string]$rule.recommendation, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $rule
        }
    }

    return $Rules.defaultAction
}

function Get-ToolkitOptimizationActionPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ActionId,
        [Parameter(Mandatory)][object]$Rules
    )

    if ([string]::Equals(
        $ActionId,
        [string]$Rules.protectedAction.id,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        return $Rules.protectedAction
    }

    foreach ($rule in @($Rules.actions)) {
        if ([string]::Equals(
            $ActionId,
            [string]$rule.id,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            return $rule
        }
    }

    return $Rules.defaultAction
}

function Get-ToolkitOptimizationOperationProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceType,
        [Parameter(Mandatory)][object]$Rules
    )

    foreach ($profile in @($Rules.operationProfiles)) {
        foreach ($supportedType in @($profile.sourceTypes)) {
            if ([string]::Equals(
                $SourceType,
                [string]$supportedType,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
                return $profile
            }
        }
    }

    return $Rules.defaultOperationProfile
}

function Get-ToolkitPreflightEnvironment {
    [CmdletBinding()]
    param()

    $isWindowsPlatform = $env:OS -eq "Windows_NT"
    $isAdministrator = $false

    if ($isWindowsPlatform) {
        try {
            $isAdministrator = Test-IsAdmin
        }
        catch {
            $isAdministrator = $false
        }
    }

    $restorePointCommand = Get-Command `
        -Name "Checkpoint-Computer" `
        -ErrorAction SilentlyContinue
    $restorePointCapability = if ($isWindowsPlatform -and $restorePointCommand) {
        "Available"
    }
    elseif (-not $isWindowsPlatform) {
        "Unsupported Platform"
    }
    else {
        "Unavailable"
    }

    return [PSCustomObject]@{
        IsWindowsPlatform      = $isWindowsPlatform
        IsAdministrator       = $isAdministrator
        RestorePointCapability = $restorePointCapability
        RestorePointReady      = (
            $restorePointCapability -eq "Available" -and
            $isAdministrator
        )
    }
}

function ConvertTo-ToolkitOptimizationPlanEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Finding,
        [object]$Rules = (Get-ToolkitOptimizationActionRules)
    )

    $name = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Name" -Default "Unnamed finding"
    $type = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Type" -Default "Unknown"
    $source = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Source"
    $version = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Version"
    $reportFile = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ReportFile"
    $action = Get-ToolkitOptimizationActionRule -Finding $Finding -Rules $Rules
    $sourceFindingId = Get-ToolkitStableId `
        -Prefix "TF" `
        -Parts (Get-ToolkitOptimizationSourceIdentityParts -Finding $Finding)
    $planId = Get-ToolkitStableId -Prefix "OP" -Parts @($sourceFindingId, [string]$action.id)
    $confidence = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Confidence" -Default ([string]$action.confidence)
    $delayedAutoStartConfiguration = Get-ToolkitFindingPropertyValue `
        -Finding $Finding `
        -Name "DelayedAutoStartConfiguration"
    if (-not [string]::IsNullOrWhiteSpace($delayedAutoStartConfiguration)) {
        try {
            $delayedAutoStartConfiguration = `
                ConvertTo-ToolkitOptimizationDelayedAutoStartConfiguration `
                    -Configuration $delayedAutoStartConfiguration
        }
        catch {
            # Keep invalid input visible so preflight denies it precisely.
        }
    }

    return New-ToolkitOptimizationPlanEntry `
        -PlanId $planId `
        -SourceFindingId $sourceFindingId `
        -SourceFinding "${type}: $name" `
        -SourceName $name `
        -SourceType $type `
        -SourceVersion $version `
        -ProposedAction ([string]$action.proposedAction) `
        -ActionId ([string]$action.id) `
        -CurrentState (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "State") `
        -Risk (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Risk" -Default "Unknown") `
        -Reason (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Reason") `
        -Confidence $confidence `
        -Category (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Category" -Default "Unknown") `
        -Vendor (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Vendor" -Default "Unknown") `
        -Recommendation (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Recommendation" -Default "Review") `
        -Source $source `
        -ReportFile $reportFile `
        -ServiceName (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServiceName") `
        -ServiceDisplayName (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServiceDisplayName") `
        -StartupType (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "StartupType") `
        -ServicePath (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServicePath") `
        -ServiceStartName (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServiceStartName") `
        -ServiceType (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ServiceType") `
        -DelayedAutoStartConfiguration $delayedAutoStartConfiguration `
        -Dependencies (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Dependencies") `
        -DependentServices (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "DependentServices") `
        -ExecutablePath (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutablePath") `
        -ExecutableCompany (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutableCompany") `
        -ExecutableProduct (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutableProduct") `
        -ExecutableSignatureStatus (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutableSignatureStatus") `
        -ExecutableSignerSubject (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "ExecutableSignerSubject") `
        -RecoveryConfiguration (Get-ToolkitFindingPropertyValue -Finding $Finding -Name "RecoveryConfiguration") `
        -RequiresConfirmation $true `
        -ConfirmationRequirement ([string]$action.confirmationRequirement) `
        -PlanStatus ([string]$action.planStatus)
}

function New-ToolkitOptimizationPlan {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()][object[]]$Findings,
        [object]$Rules = (Get-ToolkitOptimizationActionRules)
    )

    $entries = foreach ($finding in @($Findings)) {
        if ($null -ne $finding) {
            ConvertTo-ToolkitOptimizationPlanEntry -Finding $finding -Rules $Rules
        }
    }

    return @($entries | Sort-Object SourceFindingId, PlanId)
}

function ConvertTo-ToolkitOptimizationPreflightResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [object]$Rules = (Get-ToolkitOptimizationActionRules),
        [object]$Environment = (Get-ToolkitPreflightEnvironment)
    )

    $planId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "PlanId"
    $sourceFindingId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFindingId"
    $actionId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ActionId"
    $sourceFinding = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFinding"
    $sourceName = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceName"
    $sourceType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType"
    $currentState = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "CurrentState"
    $actionPolicy = Get-ToolkitOptimizationActionPolicy -ActionId $actionId -Rules $Rules
    $operationProfile = Get-ToolkitOptimizationOperationProfile -SourceType $sourceType -Rules $Rules
    $isProtected = (
        (Test-ToolkitProtectedFinding -Finding $PlanEntry -Rules $Rules) -or
        (Test-ToolkitPermanentOptimizationProtection -PlanEntry $PlanEntry)
    )
    $isCandidate = [bool]$actionPolicy.preflight.isCandidate
    $executorEligibility = if ($isCandidate) {
        Get-ToolkitOptimizationExecutorEligibility `
            -PlanEntry $PlanEntry `
            -OperationType ([string]$operationProfile.operationType) `
            -Rules $Rules
    }
    else {
        $null
    }
    $executorAllowed = (
        -not $isCandidate -or
        ($null -ne $executorEligibility -and [bool]$executorEligibility.Allowed)
    )
    $requiresCurrentState = [bool]$actionPolicy.preflight.requiresCurrentState
    $administratorRequired = (
        $isCandidate -and
        [bool]$operationProfile.requiresAdministrator
    )
    $administratorReady = (
        -not $administratorRequired -or
        [bool]$Environment.IsAdministrator
    )
    $restorePointRequired = (
        $isCandidate -and
        [bool]$actionPolicy.preflight.requiresRestorePoint
    )
    $restorePointCapability = if ($restorePointRequired) {
        Get-ToolkitFindingPropertyValue `
            -Finding $Environment `
            -Name "RestorePointCapability" `
            -Default "Unknown"
    }
    else {
        "Not Required"
    }
    $restorePointReady = (
        -not $restorePointRequired -or
        [bool]$Environment.RestorePointReady
    )
    $confirmationRequired = [bool]$PlanEntry.RequiresConfirmation
    $reversible = [bool]$operationProfile.reversible
    $reasons = [System.Collections.Generic.List[string]]::new()
    $remediation = [System.Collections.Generic.List[string]]::new()

    $currentStateValidation = if (-not $requiresCurrentState) {
        "Not Required"
    }
    elseif ([string]::IsNullOrWhiteSpace($currentState)) {
        $reasons.Add("Current state is missing for an action that requires a before-state.")
        $remediation.Add("Regenerate the source finding with a populated State value.")
        "Missing"
    }
    else {
        "Valid"
    }

    $safetyPolicyResult = if ($isProtected) {
        $reasons.Add("The plan entry matches a protected or core-component safety rule.")
        $remediation.Add("Retain the component; protected entries are not optimization candidates.")
        "Blocked - Protected"
    }
    elseif (-not $isCandidate) {
        $reasons.Add("The action policy does not define this plan entry as a change candidate.")
        $remediation.Add("Keep the entry for review; no apply operation is defined.")
        "No Change Defined"
    }
    elseif (-not $executorAllowed) {
        $reasons.Add([string]$executorEligibility.Reason)
        $remediation.Add([string]$executorEligibility.Remediation)
        [string]$executorEligibility.SafetyPolicyResult
    }
    else {
        $reasons.Add([string]$executorEligibility.Reason)
        "Allowed"
    }

    if ($isCandidate -and -not $reversible) {
        $reasons.Add("The intended operation is not safely reversible with the available inventory data.")
        $remediation.Add("Do not automate this action; use a separately reviewed recovery procedure.")
    }

    if ($isCandidate -and -not $confirmationRequired) {
        $reasons.Add("The plan entry does not require explicit confirmation.")
        $remediation.Add("Regenerate the plan with an explicit confirmation requirement.")
    }

    if (-not $administratorReady) {
        $reasons.Add("Administrator privileges are required for the intended operation.")
        $remediation.Add("Run a future confirmed apply workflow from an elevated session.")
    }

    if ($restorePointRequired -and $restorePointCapability -ne "Available") {
        $reasons.Add("System Restore capability is not available in the current PowerShell environment.")
        $remediation.Add("Verify System Restore support before any future confirmed change.")
    }
    elseif ($restorePointRequired -and -not $restorePointReady) {
        $reasons.Add("System Restore is supported but is not ready for this session.")
        $remediation.Add("Use an elevated environment with System Restore available before any future change.")
    }

    $isBlocked = (
        $isProtected -or
        -not $isCandidate -or
        -not $executorAllowed -or
        ($requiresCurrentState -and [string]::IsNullOrWhiteSpace($currentState)) -or
        -not $reversible -or
        ($isCandidate -and -not $confirmationRequired) -or
        -not $administratorReady -or
        -not $restorePointReady
    )
    $isEligible = -not $isBlocked
    $status = if ($isBlocked) {
        "Blocked"
    }
    elseif ($confirmationRequired) {
        "Confirmation Required"
    }
    else {
        "Eligible"
    }
    $confirmationStatus = if ($confirmationRequired) {
        "Required"
    }
    else {
        "Not Required"
    }
    $reversibilityStatus = if (-not $isCandidate) {
        "Not Applicable"
    }
    elseif ($reversible) {
        "Reversible"
    }
    else {
        "Not Safely Reversible"
    }

    if ($isEligible) {
        $reasons.Add("Read-only preflight prerequisites are satisfied.")
        if ($confirmationRequired) {
            $remediation.Add("Review the plan and provide explicit confirmation in a future apply workflow.")
        }
        else {
            $remediation.Add("No additional preflight remediation is required.")
        }
    }

    $preflightId = Get-ToolkitStableId `
        -Prefix "PF" `
        -Parts @($planId, $sourceFindingId, $actionId)

    return New-ToolkitOptimizationPreflightResult `
        -PreflightId $preflightId `
        -PlanId $planId `
        -SourceFindingId $sourceFindingId `
        -ActionId $actionId `
        -SourceFinding $sourceFinding `
        -SourceName $sourceName `
        -SourceType $sourceType `
        -ProposedAction (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ProposedAction") `
        -Status $status `
        -EligibilityStatus $(if ($isEligible) { "Eligible" } else { "Blocked" }) `
        -IsEligible $isEligible `
        -IsBlocked $isBlocked `
        -ConfirmationRequired $confirmationRequired `
        -ConfirmationStatus $confirmationStatus `
        -CurrentStateValidationResult $currentStateValidation `
        -SafetyPolicyResult $safetyPolicyResult `
        -AdministratorRequired $administratorRequired `
        -AdministratorReady $administratorReady `
        -RestorePointRequired $restorePointRequired `
        -RestorePointCapability $restorePointCapability `
        -RestorePointReady $restorePointReady `
        -ReversibilityStatus $reversibilityStatus `
        -Reasons ($reasons -join " ") `
        -Remediation ($remediation -join " ")
}

function New-ToolkitOptimizationPreflight {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()][object[]]$PlanEntries,
        [object]$Rules = (Get-ToolkitOptimizationActionRules),
        [object]$Environment = (Get-ToolkitPreflightEnvironment)
    )

    $results = foreach ($planEntry in @($PlanEntries)) {
        if ($null -ne $planEntry) {
            ConvertTo-ToolkitOptimizationPreflightResult `
                -PlanEntry $planEntry `
                -Rules $Rules `
                -Environment $Environment
        }
    }

    return @($results | Sort-Object PlanId, ActionId)
}

function ConvertTo-ToolkitRollbackManifestEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$PreflightResult,
        [object]$Rules = (Get-ToolkitOptimizationActionRules)
    )

    $planId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "PlanId"
    $sourceFindingId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFindingId"
    $actionId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ActionId"
    $sourceName = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceName"
    $sourceType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType"
    $currentState = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "CurrentState"
    $actionPolicy = Get-ToolkitOptimizationActionPolicy -ActionId $actionId -Rules $Rules
    $operationProfile = Get-ToolkitOptimizationOperationProfile -SourceType $sourceType -Rules $Rules
    $isCandidate = [bool]$actionPolicy.preflight.isCandidate
    $delayedAutoStartProperty = `
        $PlanEntry.PSObject.Properties["DelayedAutoStartConfiguration"]
    $delayedAutoStartConfiguration = ""
    if ($null -ne $delayedAutoStartProperty) {
        try {
            $delayedAutoStartConfiguration = `
                ConvertTo-ToolkitOptimizationDelayedAutoStartConfiguration `
                    -Configuration $delayedAutoStartProperty.Value
        }
        catch {
            $delayedAutoStartConfiguration = `
                [string]$delayedAutoStartProperty.Value
        }
    }

    $beforeState = [ordered]@{
        CurrentState   = $currentState
        SourceName     = $sourceName
        SourceType     = $sourceType
        SourceVersion  = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceVersion"
        Source         = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Source"
        Vendor         = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Vendor"
        Category       = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Category"
        Risk           = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Risk"
        Recommendation = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Recommendation"
        ReportFile     = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ReportFile"
        ServiceName    = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ServiceName"
        ServiceDisplayName = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ServiceDisplayName"
        StartupType    = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "StartupType"
        ServicePath    = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ServicePath"
        ServiceStartName = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ServiceStartName"
        ServiceType    = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ServiceType"
        DelayedAutoStartConfiguration = $delayedAutoStartConfiguration
        Dependencies   = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Dependencies"
        DependentServices = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "DependentServices"
        ExecutablePath = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ExecutablePath"
        ExecutableCompany = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ExecutableCompany"
        ExecutableProduct = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ExecutableProduct"
        ExecutableSignatureStatus = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ExecutableSignatureStatus"
        ExecutableSignerSubject = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ExecutableSignerSubject"
        RecoveryConfiguration = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "RecoveryConfiguration"
    }
    $requiredBeforeStateFields = @($operationProfile.requiredBeforeStateFields)
    $missingBeforeStateFields = @(
        foreach ($field in $requiredBeforeStateFields) {
            if ([string]::IsNullOrWhiteSpace([string]$beforeState[$field])) {
                [string]$field
            }
        }
    )
    $beforeStateCaptured = $missingBeforeStateFields.Count -eq 0
    $beforeStateSnapshot = $beforeState | ConvertTo-Json -Compress
    $beforeStateHash = Get-ToolkitStableId -Prefix "BS" -Parts @($beforeStateSnapshot)
    $isReversible = (
        $isCandidate -and
        [bool]$operationProfile.reversible -and
        $beforeStateCaptured
    )
    $reversibilityStatement = if (-not $isCandidate) {
        "No rollback operation is defined because this entry is not a change candidate."
    }
    elseif (-not [bool]$operationProfile.reversible) {
        [string]$operationProfile.reversibilityStatement
    }
    elseif (-not $beforeStateCaptured) {
        "The operation is potentially reversible, but the required before-state was not captured."
    }
    else {
        [string]$operationProfile.reversibilityStatement
    }
    $manifestId = Get-ToolkitStableId `
        -Prefix "RM" `
        -Parts @($planId, $actionId, $beforeStateHash)

    $targetIdentity = Get-ToolkitFindingPropertyValue `
        -Finding $PlanEntry `
        -Name "ServiceName" `
        -Default $sourceName

    return New-ToolkitRollbackManifestEntry `
        -ManifestId $manifestId `
        -PreflightId (Get-ToolkitFindingPropertyValue -Finding $PreflightResult -Name "PreflightId") `
        -PlanId $planId `
        -SourceFindingId $sourceFindingId `
        -ActionId $actionId `
        -SourceFinding (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFinding") `
        -SourceName $sourceName `
        -SourceType $sourceType `
        -TargetIdentity $targetIdentity `
        -OperationType ([string]$operationProfile.operationType) `
        -IntendedOperation ([string]$operationProfile.intendedOperation) `
        -BeforeStateSnapshot $beforeStateSnapshot `
        -BeforeStateHash $beforeStateHash `
        -BeforeStateCaptured $beforeStateCaptured `
        -RequiredBeforeStateFields ($requiredBeforeStateFields -join ", ") `
        -MissingBeforeStateFields ($missingBeforeStateFields -join ", ") `
        -IsReversible $isReversible `
        -ReversibilityStatement $reversibilityStatement `
        -RestorePointRequired ([bool]$PreflightResult.RestorePointRequired) `
        -SafetyPolicyResult (Get-ToolkitFindingPropertyValue -Finding $PreflightResult -Name "SafetyPolicyResult")
}

function New-ToolkitRollbackManifest {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()][object[]]$PlanEntries,
        [AllowEmptyCollection()][object[]]$PreflightResults,
        [object]$Rules = (Get-ToolkitOptimizationActionRules)
    )

    $manifests = foreach ($planEntry in @($PlanEntries)) {
        if ($null -eq $planEntry) {
            continue
        }

        $preflightResult = @(
            $PreflightResults |
                Where-Object {
                    [string]$_.PlanId -eq [string]$planEntry.PlanId -and
                    [string]$_.ActionId -eq [string]$planEntry.ActionId
                }
        ) | Select-Object -First 1

        if ($null -eq $preflightResult) {
            throw "Preflight result not found for plan entry: $($planEntry.PlanId)"
        }

        ConvertTo-ToolkitRollbackManifestEntry `
            -PlanEntry $planEntry `
            -PreflightResult $preflightResult `
            -Rules $Rules
    }

    return @($manifests | Sort-Object PlanId, ActionId)
}

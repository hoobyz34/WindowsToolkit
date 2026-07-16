Import-Module (Join-Path $PSScriptRoot "Models.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Optimizer.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Discovery.psm1") -Force

function ConvertTo-ToolkitExecutionBoolean {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($Value -is [bool]) {
        return $Value
    }

    $parsed = $false
    if ([bool]::TryParse([string]$Value, [ref]$parsed)) {
        return $parsed
    }

    return $false
}

function Test-ToolkitExecutionStringEquals {
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

function Get-ToolkitOptimizationExecutionPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$Rules
    )

    $operationType = Get-ToolkitFindingPropertyValue `
        -Finding $RollbackManifest `
        -Name "OperationType"
    $eligibility = Get-ToolkitOptimizationExecutorEligibility `
        -PlanEntry $PlanEntry `
        -OperationType $operationType `
        -Rules $Rules

    if ($eligibility.Allowed) {
        return $eligibility.ExecutionPolicy
    }

    return $null
}

function Test-ToolkitPermanentExecutorProtection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry
    )

    return Test-ToolkitPermanentOptimizationProtection -PlanEntry $PlanEntry
}

function Test-ToolkitExecutorLiteralIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskName,
        [Parameter(Mandatory)][string]$TaskPath
    )

    return Test-ToolkitOptimizationLiteralTaskIdentity `
        -TaskName $TaskName `
        -TaskPath $TaskPath
}

function Test-ToolkitExecutorTargetScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    $targetIdentity = Get-ToolkitFindingPropertyValue -Finding $RollbackManifest -Name "TargetIdentity"
    $scope = Test-ToolkitOptimizationExecutorScope `
        -PlanEntry $PlanEntry `
        -ExecutionPolicy $ExecutionPolicy
    if (-not $scope.Allowed) {
        return $scope
    }

    $expectedTargetIdentity = if (
        Test-ToolkitExecutionStringEquals $ExecutionPolicy.ExecutorId "DisableService"
    ) {
        Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ServiceName"
    }
    else {
        Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceName"
    }

    if (-not (Test-ToolkitExecutionStringEquals $targetIdentity $expectedTargetIdentity)) {
        return [PSCustomObject]@{
            Allowed      = $false
            DecisionCode = "TargetScopeMismatch"
            Reason       = "The rollback target identity does not match the exact allowlisted target."
            Remediation  = "Regenerate the rollback manifest from the current plan and preflight result."
        }
    }

    return $scope
}

function Get-ToolkitExecutorCurrentObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    switch ([string]$ExecutionPolicy.ExecutorId) {
        "DisableScheduledTask" {
            $expectedName = [string]$RollbackManifest.TargetIdentity
            $expectedPath = [string]$PlanEntry.Source
            $tasks = @(
                Get-ScheduledTask `
                    -TaskName $expectedName `
                    -TaskPath $expectedPath `
                    -ErrorAction Stop
            )

            if ($tasks.Count -ne 1) {
                throw "Expected exactly one scheduled task; found $($tasks.Count)."
            }

            $task = $tasks[0]
            if (
                -not (Test-ToolkitExecutionStringEquals $task.TaskName $expectedName) -or
                -not (Test-ToolkitExecutionStringEquals $task.TaskPath $expectedPath)
            ) {
                throw "The live scheduled-task identity does not exactly match the approved target."
            }

            $author = ([string]$task.Author).Trim()
            $authorAllowed = @(
                $ExecutionPolicy.TaskAuthorPatterns |
                    Where-Object {
                        $pattern = [string]$_
                        if (Test-ToolkitExecutionStringEquals $pattern "HP") {
                            (Test-ToolkitExecutionStringEquals $author "HP") -or
                            $author.StartsWith(
                                "HP ",
                                [System.StringComparison]::OrdinalIgnoreCase
                            ) -or
                            $author.StartsWith(
                                "HP,",
                                [System.StringComparison]::OrdinalIgnoreCase
                            )
                        }
                        else {
                            $author.StartsWith(
                                $pattern,
                                [System.StringComparison]::OrdinalIgnoreCase
                            )
                        }
                    }
            ).Count -gt 0

            if (-not $authorAllowed) {
                throw "The live scheduled-task author is not an allowlisted HP author."
            }

            return [PSCustomObject]@{
                TaskName = [string]$task.TaskName
                TaskPath = [string]$task.TaskPath
                State    = [string]$task.State
                Author   = $author
            }
        }

        "DisableService" {
            $expectedName = [string]$RollbackManifest.TargetIdentity
            $serviceContract = Get-ToolkitOptimizationServiceExecutorContract
            if (
                -not (Test-ToolkitExecutionStringEquals $expectedName $serviceContract.ServiceName) -or
                -not (Test-ToolkitOptimizationLiteralServiceIdentity $expectedName)
            ) {
                throw "The requested service identity is not the fixed allowlisted service."
            }

            $service = Get-ToolkitServiceInventoryRecord `
                -Name $expectedName `
                -IncludeExecutableIdentity

            if (
                -not (Test-ToolkitExecutionStringEquals $service.Name $ExecutionPolicy.ServiceName) -or
                -not (Test-ToolkitExecutionStringEquals $service.DisplayName $ExecutionPolicy.ServiceDisplayName) -or
                -not (Test-ToolkitExecutionStringEquals $service.StartName $ExecutionPolicy.ServiceStartName) -or
                -not (Test-ToolkitExecutionStringEquals $service.ServiceType $ExecutionPolicy.ServiceType) -or
                -not (Test-ToolkitExecutionStringEquals $service.ExecutableCompany $ExecutionPolicy.ExecutableCompany) -or
                -not (Test-ToolkitExecutionStringEquals $service.ExecutableProduct $ExecutionPolicy.ExecutableProduct) -or
                -not (Test-ToolkitExecutionStringEquals $service.ExecutableSignatureStatus $ExecutionPolicy.ExecutableSignatureStatus) -or
                ([string]$service.ExecutableSignerSubject).IndexOf(
                    [string]$ExecutionPolicy.ExecutableSignerSubjectPattern,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -lt 0 -or
                -not (Test-ToolkitExecutionStringEquals $service.PathName $service.ExecutablePath) -or
                -not ([string]$service.ExecutablePath).EndsWith(
                    [string]$ExecutionPolicy.ExecutablePathSuffix,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -or
                ([string]$service.ExecutablePath).IndexOf(
                    [string]$ExecutionPolicy.ExecutablePathMarker,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -lt 0 -or
                -not (Test-ToolkitExecutionStringEquals `
                    ([System.IO.Path]::GetFileName([string]$service.ExecutablePath)) `
                    $ExecutionPolicy.ExecutableFileName)
            ) {
                throw "The live service identity does not exactly match the allowlisted HP Insights Analytics service."
            }

            return [PSCustomObject]@{
                Name                  = [string]$service.Name
                DisplayName           = [string]$service.DisplayName
                State                 = [string]$service.State
                StartupType           = [string]$service.StartupType
                ServicePath           = [string]$service.PathName
                ServiceStartName      = [string]$service.StartName
                ServiceType           = [string]$service.ServiceType
                DelayedAutoStartConfiguration = [string]$service.DelayedAutoStartConfiguration
                Dependencies          = [string]$service.Dependencies
                DependentServices     = [string]$service.DependentServices
                ExecutablePath        = [string]$service.ExecutablePath
                ExecutableCompany     = [string]$service.ExecutableCompany
                ExecutableProduct     = [string]$service.ExecutableProduct
                ExecutableSignatureStatus = [string]$service.ExecutableSignatureStatus
                ExecutableSignerSubject = [string]$service.ExecutableSignerSubject
                RecoveryConfiguration = [string]$service.RecoveryConfiguration
            }
        }

        default {
            throw "Unsupported executor."
        }
    }
}

function Test-ToolkitExecutorServiceSafetyMetadataMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$CurrentObject,
        [Parameter(Mandatory)][object]$ReferenceObject,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    try {
        $dependencies = ConvertFrom-ToolkitOptimizationStringArray `
            -Json ([string]$CurrentObject.Dependencies)
        $dependentServices = ConvertFrom-ToolkitOptimizationStringArray `
            -Json ([string]$CurrentObject.DependentServices)
        $currentDelayedAutoStart = `
            ConvertTo-ToolkitOptimizationDelayedAutoStartConfiguration `
                -Configuration $CurrentObject.DelayedAutoStartConfiguration
        $referenceDelayedAutoStart = `
            ConvertTo-ToolkitOptimizationDelayedAutoStartConfiguration `
                -Configuration $ReferenceObject.DelayedAutoStartConfiguration
    }
    catch {
        return $false
    }

    return (
        (Test-ToolkitExecutionStringEquals $CurrentObject.Name $ExecutionPolicy.ServiceName) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.DisplayName $ExecutionPolicy.ServiceDisplayName) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.Name $ReferenceObject.ServiceName) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.DisplayName $ReferenceObject.ServiceDisplayName) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ServicePath $ReferenceObject.ServicePath) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ServicePath $CurrentObject.ExecutablePath) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ServiceStartName $ReferenceObject.ServiceStartName) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ServiceStartName $ExecutionPolicy.ServiceStartName) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ServiceType $ReferenceObject.ServiceType) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ServiceType $ExecutionPolicy.ServiceType) -and
        $currentDelayedAutoStart -ceq $referenceDelayedAutoStart -and
        (Test-ToolkitOptimizationDelayedAutoStartConfiguration `
            $currentDelayedAutoStart) -and
        (Test-ToolkitOptimizationCollectionSetEquals `
            $dependencies `
            $ExecutionPolicy.RequiredDependencies) -and
        (Test-ToolkitOptimizationCollectionSetEquals `
            $dependentServices `
            $ExecutionPolicy.AllowedDependentServices) -and
        [string]$CurrentObject.Dependencies -ceq [string]$ReferenceObject.Dependencies -and
        [string]$CurrentObject.DependentServices -ceq [string]$ReferenceObject.DependentServices -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ExecutablePath $ReferenceObject.ExecutablePath) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ExecutableCompany $ReferenceObject.ExecutableCompany) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ExecutableCompany $ExecutionPolicy.ExecutableCompany) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ExecutableProduct $ReferenceObject.ExecutableProduct) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ExecutableProduct $ExecutionPolicy.ExecutableProduct) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ExecutableSignatureStatus $ReferenceObject.ExecutableSignatureStatus) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ExecutableSignatureStatus $ExecutionPolicy.ExecutableSignatureStatus) -and
        (Test-ToolkitExecutionStringEquals $CurrentObject.ExecutableSignerSubject $ReferenceObject.ExecutableSignerSubject) -and
        ([string]$CurrentObject.ExecutableSignerSubject).IndexOf(
            [string]$ExecutionPolicy.ExecutableSignerSubjectPattern,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -ge 0 -and
        [string]$CurrentObject.RecoveryConfiguration -ceq
            [string]$ReferenceObject.RecoveryConfiguration -and
        (Test-ToolkitOptimizationRecoveryConfiguration `
            ([string]$CurrentObject.RecoveryConfiguration))
    )
}

function Test-ToolkitExecutorBeforeStateMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$CurrentObject,
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$BeforeState,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    switch ([string]$ExecutionPolicy.ExecutorId) {
        "DisableScheduledTask" {
            return (
                (Test-ToolkitExecutionStringEquals $CurrentObject.State $PlanEntry.CurrentState) -and
                (Test-ToolkitExecutionStringEquals $CurrentObject.State $BeforeState.CurrentState)
            )
        }

        "DisableService" {
            return (
                (Test-ToolkitExecutorServiceSafetyMetadataMatch `
                    -CurrentObject $CurrentObject `
                    -ReferenceObject $BeforeState `
                    -ExecutionPolicy $ExecutionPolicy) -and
                (Test-ToolkitExecutorServiceSafetyMetadataMatch `
                    -CurrentObject $CurrentObject `
                    -ReferenceObject $PlanEntry `
                    -ExecutionPolicy $ExecutionPolicy) -and
                (Test-ToolkitExecutionStringEquals $CurrentObject.State $PlanEntry.CurrentState) -and
                (Test-ToolkitExecutionStringEquals $CurrentObject.State $BeforeState.CurrentState) -and
                (Test-ToolkitExecutionStringEquals $CurrentObject.StartupType $PlanEntry.StartupType) -and
                (Test-ToolkitExecutionStringEquals $CurrentObject.StartupType $BeforeState.StartupType)
            )
        }

        default {
            return $false
        }
    }
}

function Test-ToolkitExecutorTargetState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$CurrentObject,
        [Parameter(Mandatory)][object]$ExecutionPolicy,
        [AllowNull()][object]$BeforeState
    )

    if (Test-ToolkitExecutionStringEquals $ExecutionPolicy.ExecutorId "DisableService") {
        return (
            (Test-ToolkitExecutionStringEquals $CurrentObject.State $ExecutionPolicy.TargetState) -and
            (Test-ToolkitExecutionStringEquals $CurrentObject.StartupType $ExecutionPolicy.TargetStartupType) -and
            $null -ne $BeforeState -and
            (Test-ToolkitExecutorServiceSafetyMetadataMatch `
                -CurrentObject $CurrentObject `
                -ReferenceObject $BeforeState `
                -ExecutionPolicy $ExecutionPolicy)
        )
    }

    return Test-ToolkitExecutionStringEquals `
        $CurrentObject.State `
        $ExecutionPolicy.TargetState
}

function Get-ToolkitExecutorObservedState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$CurrentObject,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    if (Test-ToolkitExecutionStringEquals $ExecutionPolicy.ExecutorId "DisableService") {
        return "State=$($CurrentObject.State);StartupType=$($CurrentObject.StartupType)"
    }

    return [string]$CurrentObject.State
}

function New-ToolkitDeniedExecutionGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DecisionCode,
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$Remediation
    )

    return [PSCustomObject]@{
        Allowed           = $false
        DecisionCode      = $DecisionCode
        PolicyAllowed     = $false
        PreflightValid    = $false
        ManifestValid     = $false
        CurrentStateValid = $false
        ExecutionPolicy   = $null
        Reason            = $Reason
        Remediation       = $Remediation
    }
}

function Test-ToolkitOptimizationExecutionGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [AllowNull()][object]$PreflightResult,
        [AllowNull()][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$Rules,
        [Parameter(Mandatory)][object]$Environment
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $remediation = [System.Collections.Generic.List[string]]::new()
    $decisionCode = "Ready"
    $policyAllowed = $false
    $preflightValid = $false
    $manifestValid = $false
    $currentStateValid = $false
    $executionPolicy = $null
    $planId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "PlanId"
    $sourceFindingId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFindingId"
    $actionId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ActionId"
    $expectedSourceFindingId = Get-ToolkitStableId `
        -Prefix "TF" `
        -Parts (Get-ToolkitOptimizationSourceIdentityParts -Finding $PlanEntry)
    $expectedPlanId = Get-ToolkitStableId `
        -Prefix "OP" `
        -Parts @($expectedSourceFindingId, $actionId)
    $operationProfile = Get-ToolkitOptimizationOperationProfile `
        -SourceType (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType") `
        -Rules $Rules
    $staticEligibility = Get-ToolkitOptimizationExecutorEligibility `
        -PlanEntry $PlanEntry `
        -OperationType ([string]$operationProfile.operationType) `
        -Rules $Rules

    if (
        (Test-ToolkitPermanentExecutorProtection -PlanEntry $PlanEntry) -or
        (Test-ToolkitProtectedFinding -Finding $PlanEntry -Rules $Rules)
    ) {
        $decisionCode = "ProtectedComponent"
        $reasons.Add("The plan entry matches a permanent protected-component policy.")
        $remediation.Add("Retain the protected component; executor policy cannot override this block.")
    }
    elseif ($null -eq $PreflightResult) {
        $decisionCode = "MissingPreflight"
        $reasons.Add("No preflight result exists for the plan action.")
        $remediation.Add("Regenerate and review the optimizer preflight report.")
    }
    elseif ($null -eq $RollbackManifest) {
        $decisionCode = "MissingRollbackManifest"
        $reasons.Add("No rollback manifest exists for the plan action.")
        $remediation.Add("Regenerate the rollback manifest with a complete before-state snapshot.")
    }
    elseif (
        -not (Test-ToolkitExecutionStringEquals $sourceFindingId $expectedSourceFindingId) -or
        -not (Test-ToolkitExecutionStringEquals $planId $expectedPlanId)
    ) {
        $decisionCode = "InvalidPlanIdentity"
        $reasons.Add("The plan identity does not match its source and action fields.")
        $remediation.Add("Discard altered reports and regenerate the optimizer plan.")
    }
    elseif (-not $staticEligibility.Allowed) {
        $decisionCode = [string]$staticEligibility.DecisionCode
        $reasons.Add([string]$staticEligibility.Reason)
        $remediation.Add([string]$staticEligibility.Remediation)
    }
    elseif (-not (ConvertTo-ToolkitExecutionBoolean $Environment.IsAdministrator)) {
        $decisionCode = "AdministratorRequired"
        $reasons.Add("The current process is not running with administrator privileges.")
        $remediation.Add("Use an elevated session only after reviewing the dry-run output.")
    }
    elseif (
        -not (ConvertTo-ToolkitExecutionBoolean $Environment.RestorePointReady) -or
        -not (Test-ToolkitExecutionStringEquals $Environment.RestorePointCapability "Available")
    ) {
        $decisionCode = "RestorePointNotReady"
        $reasons.Add("System Restore capability is not ready for the current process.")
        $remediation.Add("Resolve restore-point readiness before attempting an allowlisted change; the executor will not create a restore point.")
    }
    else {
        $expectedPreflightId = Get-ToolkitStableId `
            -Prefix "PF" `
            -Parts @($planId, $sourceFindingId, $actionId)
        $currentPreflight = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry $PlanEntry `
            -Rules $Rules `
            -Environment $Environment
        $preflightIdentityValid = (
            (Test-ToolkitExecutionStringEquals $PreflightResult.PreflightId $expectedPreflightId) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.PlanId $planId) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.SourceFindingId $sourceFindingId) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.ActionId $actionId)
        )
        $preflightStateValid = (
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.IsEligible) -and
            -not (ConvertTo-ToolkitExecutionBoolean $PreflightResult.IsBlocked) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.EligibilityStatus "Eligible") -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.Status "Confirmation Required") -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.ConfirmationRequired) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.CurrentStateValidationResult "Valid") -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.SafetyPolicyResult "Allowed") -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.ReversibilityStatus "Reversible") -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.AdministratorRequired) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.AdministratorReady) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.RestorePointRequired) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.RestorePointReady) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.Status $currentPreflight.Status) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.EligibilityStatus $currentPreflight.EligibilityStatus) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.CurrentStateValidationResult $currentPreflight.CurrentStateValidationResult) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.SafetyPolicyResult $currentPreflight.SafetyPolicyResult) -and
            (Test-ToolkitExecutionStringEquals $PreflightResult.ReversibilityStatus $currentPreflight.ReversibilityStatus) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.IsEligible) -eq
                (ConvertTo-ToolkitExecutionBoolean $currentPreflight.IsEligible) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.IsBlocked) -eq
                (ConvertTo-ToolkitExecutionBoolean $currentPreflight.IsBlocked) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.AdministratorReady) -eq
                (ConvertTo-ToolkitExecutionBoolean $currentPreflight.AdministratorReady) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.RestorePointReady) -eq
                (ConvertTo-ToolkitExecutionBoolean $currentPreflight.RestorePointReady)
        )
        $preflightValid = $preflightIdentityValid -and $preflightStateValid

        if (-not $preflightValid) {
            $decisionCode = "InvalidOrStalePreflight"
            $reasons.Add("The preflight result is failed, stale, mismatched, or no longer valid in the current environment.")
            $remediation.Add("Regenerate preflight immediately before a future Apply attempt.")
        }
        else {
            $expectedManifest = ConvertTo-ToolkitRollbackManifestEntry `
                -PlanEntry $PlanEntry `
                -PreflightResult $currentPreflight `
                -Rules $Rules
            $expectedBeforeStateHash = Get-ToolkitStableId `
                -Prefix "BS" `
                -Parts @([string]$RollbackManifest.BeforeStateSnapshot)
            $manifestValid = (
                (Test-ToolkitExecutionStringEquals $RollbackManifest.PlanId $planId) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.SourceFindingId $sourceFindingId) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.ActionId $actionId) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.PreflightId $PreflightResult.PreflightId) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.SourceFinding $expectedManifest.SourceFinding) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.SourceName $expectedManifest.SourceName) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.SourceType $expectedManifest.SourceType) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.BeforeStateHash $expectedBeforeStateHash) -and
                (ConvertTo-ToolkitExecutionBoolean $RollbackManifest.BeforeStateCaptured) -and
                (ConvertTo-ToolkitExecutionBoolean $RollbackManifest.IsReversible) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.SafetyPolicyResult "Allowed") -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.ManifestId $expectedManifest.ManifestId) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.OperationType $expectedManifest.OperationType) -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.TargetIdentity $expectedManifest.TargetIdentity) -and
                [string]$RollbackManifest.BeforeStateSnapshot -ceq
                    [string]$expectedManifest.BeforeStateSnapshot -and
                (Test-ToolkitExecutionStringEquals $RollbackManifest.BeforeStateHash $expectedManifest.BeforeStateHash) -and
                [string]$RollbackManifest.RequiredBeforeStateFields -ceq
                    [string]$expectedManifest.RequiredBeforeStateFields -and
                [string]$RollbackManifest.MissingBeforeStateFields -ceq
                    [string]$expectedManifest.MissingBeforeStateFields
            )

            if (-not $manifestValid) {
                $decisionCode = "InvalidRollbackManifest"
                $reasons.Add("The rollback manifest is incomplete, non-reversible, mismatched, or has an invalid before-state hash.")
                $remediation.Add("Regenerate the rollback manifest from the current eligible plan and preflight result.")
            }
            else {
                $executionPolicy = Get-ToolkitOptimizationExecutionPolicy `
                    -PlanEntry $PlanEntry `
                    -RollbackManifest $RollbackManifest `
                    -Rules $Rules
                $policyAllowed = $null -ne $executionPolicy

                if (-not $policyAllowed) {
                    $decisionCode = "ExecutionPolicyDenied"
                    $reasons.Add("No valid execution policy matches the fixed executor safety contract.")
                    $remediation.Add("Restore the trusted policy data and regenerate the optimizer reports.")
                }
                else {
                    $scope = Test-ToolkitExecutorTargetScope `
                        -PlanEntry $PlanEntry `
                        -RollbackManifest $RollbackManifest `
                        -ExecutionPolicy $executionPolicy

                    if (-not $scope.Allowed) {
                        $decisionCode = $scope.DecisionCode
                        $reasons.Add($scope.Reason)
                        $remediation.Add($scope.Remediation)
                    }
                    else {
                        try {
                            $beforeState = [string]$RollbackManifest.BeforeStateSnapshot |
                                ConvertFrom-Json -ErrorAction Stop
                            $currentObject = Get-ToolkitExecutorCurrentObject `
                                -PlanEntry $PlanEntry `
                                -RollbackManifest $RollbackManifest `
                                -ExecutionPolicy $executionPolicy
                            $observedState = Get-ToolkitExecutorObservedState `
                                -CurrentObject $currentObject `
                                -ExecutionPolicy $executionPolicy
                            $currentStateValid = Test-ToolkitExecutorBeforeStateMatch `
                                -CurrentObject $currentObject `
                                -PlanEntry $PlanEntry `
                                -BeforeState $beforeState `
                                -ExecutionPolicy $executionPolicy
                        }
                        catch {
                            $currentStateValid = $false
                            $reasons.Add("Current target validation failed: $($_.Exception.Message)")
                        }

                        if (-not $currentStateValid) {
                            $decisionCode = "StaleCurrentState"
                            $reasons.Add("The live task identity or current state no longer matches the plan and rollback snapshot.")
                            $remediation.Add("Regenerate the plan, preflight result, and rollback manifest before applying.")
                        }
                        elseif (Test-ToolkitExecutorTargetState `
                            -CurrentObject $currentObject `
                            -ExecutionPolicy $executionPolicy `
                            -BeforeState $beforeState) {
                            $currentStateValid = $false
                            $decisionCode = "AlreadyAtTargetState"
                            $reasons.Add("The live object is already in the execution policy target state.")
                            $remediation.Add("No action is required; regenerate reports if the plan still proposes this change.")
                        }
                    }
                }
            }
        }
    }

    $allowed = (
        $decisionCode -eq "Ready" -and
        $policyAllowed -and
        $preflightValid -and
        $manifestValid -and
        $currentStateValid
    )

    if ($allowed) {
        $reasons.Add("All executor safety gates are satisfied.")
        $remediation.Add("Use explicit Apply and confirmation to execute, or omit Apply for preview.")
    }

    return [PSCustomObject]@{
        Allowed           = $allowed
        DecisionCode      = $decisionCode
        PolicyAllowed     = $policyAllowed
        PreflightValid    = $preflightValid
        ManifestValid     = $manifestValid
        CurrentStateValid = $currentStateValid
        ExecutionPolicy   = $executionPolicy
        Reason            = $reasons -join " "
        Remediation       = $remediation -join " "
    }
}

function Test-ToolkitRollbackExecutionRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$ExecutionResult,
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$PreflightResult,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    $statusAllowsRollback = @(
        "Executed",
        "FailedAfterStateChange",
        "Indeterminate"
    ) -contains [string]$ExecutionResult.Status
    $rollbackStatusAllowsRollback = @(
        "Available",
        "Required - Not Executed"
    ) -contains [string]$ExecutionResult.RollbackStatus

    return (
        (Test-ToolkitExecutionStringEquals $ExecutionResult.PlanId $PlanEntry.PlanId) -and
        (Test-ToolkitExecutionStringEquals $ExecutionResult.PreflightId $PreflightResult.PreflightId) -and
        (Test-ToolkitExecutionStringEquals $ExecutionResult.ManifestId $RollbackManifest.ManifestId) -and
        (Test-ToolkitExecutionStringEquals $ExecutionResult.ActionId $PlanEntry.ActionId) -and
        (Test-ToolkitExecutionStringEquals $ExecutionResult.ExecutorId $ExecutionPolicy.ExecutorId) -and
        (Test-ToolkitExecutionStringEquals $ExecutionResult.OperationType $RollbackManifest.OperationType) -and
        (Test-ToolkitExecutionStringEquals $ExecutionResult.BeforeStateHash $RollbackManifest.BeforeStateHash) -and
        (ConvertTo-ToolkitExecutionBoolean $ExecutionResult.MutationAttempted) -and
        (ConvertTo-ToolkitExecutionBoolean $ExecutionResult.ShouldProcessApproved) -and
        (ConvertTo-ToolkitExecutionBoolean $ExecutionResult.ConfirmationProvided) -and
        $statusAllowsRollback -and
        $rollbackStatusAllowsRollback
    )
}

function New-ToolkitExecutionAuditRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [AllowNull()][object]$PreflightResult,
        [AllowNull()][object]$RollbackManifest,
        [AllowNull()][object]$ExecutionPolicy,
        [Parameter(Mandatory)][object]$Gate,
        [Parameter(Mandatory)][string]$AttemptMode,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$DecisionCode,
        [Parameter(Mandatory)][bool]$Applied,
        [Parameter(Mandatory)][bool]$MutationAttempted,
        [Parameter(Mandatory)][bool]$ShouldProcessApproved,
        [Parameter(Mandatory)][bool]$ConfirmationProvided,
        [string]$ObservedStateAfter = "",
        [Parameter(Mandatory)][bool]$RollbackRequired,
        [Parameter(Mandatory)][string]$RollbackStatus,
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$Remediation
    )

    $attemptedAtUtc = [datetime]::UtcNow
    $executionId = Get-ToolkitStableId `
        -Prefix "EX" `
        -Parts @(
            Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "PlanId"
            Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ActionId"
            $(if ($null -eq $RollbackManifest) { "" } else {
                Get-ToolkitFindingPropertyValue -Finding $RollbackManifest -Name "ManifestId"
            })
            $AttemptMode
            $attemptedAtUtc.ToString("o")
        )
    $operationType = if ($null -eq $RollbackManifest) {
        "Unknown"
    }
    else {
        Get-ToolkitFindingPropertyValue `
            -Finding $RollbackManifest `
            -Name "OperationType" `
            -Default "Unknown"
    }

    return New-ToolkitOptimizationExecutionResult `
        -ExecutionId $executionId `
        -PlanId (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "PlanId") `
        -PreflightId $(if ($null -eq $PreflightResult) { "" } else {
            Get-ToolkitFindingPropertyValue -Finding $PreflightResult -Name "PreflightId"
        }) `
        -ManifestId $(if ($null -eq $RollbackManifest) { "" } else {
            Get-ToolkitFindingPropertyValue -Finding $RollbackManifest -Name "ManifestId"
        }) `
        -ActionId (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ActionId") `
        -SourceFinding (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFinding") `
        -SourceName (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceName") `
        -SourceType (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType") `
        -OperationType $operationType `
        -ExecutorId $(if ($null -eq $ExecutionPolicy) { "" } else {
            [string]$ExecutionPolicy.ExecutorId
        }) `
        -AttemptMode $AttemptMode `
        -Status $Status `
        -DecisionCode $DecisionCode `
        -Applied $Applied `
        -MutationAttempted $MutationAttempted `
        -ShouldProcessApproved $ShouldProcessApproved `
        -PolicyAllowed ([bool]$Gate.PolicyAllowed) `
        -PreflightValid ([bool]$Gate.PreflightValid) `
        -ManifestValid ([bool]$Gate.ManifestValid) `
        -CurrentStateValid ([bool]$Gate.CurrentStateValid) `
        -ConfirmationProvided $ConfirmationProvided `
        -ObservedStateAfter $ObservedStateAfter `
        -RollbackRequired $RollbackRequired `
        -RollbackStatus $RollbackStatus `
        -Reason $Reason `
        -Remediation $Remediation `
        -BeforeStateHash $(if ($null -eq $RollbackManifest) { "" } else {
            Get-ToolkitFindingPropertyValue -Finding $RollbackManifest -Name "BeforeStateHash"
        }) `
        -RollbackOperationType $(if ($null -eq $ExecutionPolicy) { "" } else {
            [string]$ExecutionPolicy.RollbackOperationType
        }) `
        -RollbackTargetState $(if ($null -eq $ExecutionPolicy) { "" } else {
            [string]$ExecutionPolicy.RollbackTargetState
        }) `
        -AttemptedAtUtc $attemptedAtUtc
}

function Invoke-ToolkitOptimizationRollback {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$PreflightResult,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$ExecutionResult,
        [switch]$Apply,
        [switch]$Confirmed
    )

    $rules = Get-ToolkitOptimizationActionRules
    $environment = Get-ToolkitPreflightEnvironment
    $operationProfile = Get-ToolkitOptimizationOperationProfile `
        -SourceType ([string]$PlanEntry.SourceType) `
        -Rules $rules
    $policy = Get-ToolkitOptimizationExecutionPolicyMatch `
        -PlanEntry $PlanEntry `
        -OperationType ([string]$operationProfile.operationType) `
        -Rules $rules
    $gate = New-ToolkitDeniedExecutionGate `
        -DecisionCode "RollbackValidationFailed" `
        -Reason "Rollback validation has not completed." `
        -Remediation "Regenerate and review the optimizer artifacts."
    $reason = ""
    $remediation = ""
    $beforeState = $null
    $currentObject = $null
    $approvedRollbackState = ""
    $approvedRollbackStartupType = ""
    $rollbackMutationAttempted = $false
    $valid = $true

    try {
        $expectedPreflight = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry $PlanEntry `
            -Rules $rules `
            -Environment $environment
        $expectedManifest = ConvertTo-ToolkitRollbackManifestEntry `
            -PlanEntry $PlanEntry `
            -PreflightResult $expectedPreflight `
            -Rules $rules
        $beforeState = [string]$RollbackManifest.BeforeStateSnapshot |
            ConvertFrom-Json -ErrorAction Stop

        if ($null -eq $policy) {
            throw "No fixed execution policy matches the rollback artifacts."
        }
        if (
            -not (Test-ToolkitExecutionStringEquals $policy.ExecutorId "DisableService") -or
            -not (Test-ToolkitExecutionStringEquals $policy.RollbackOperationType "RestoreServiceConfiguration")
        ) {
            throw "Rollback is only implemented for the exact HP Insights Analytics service action."
        }
        if (
            -not (ConvertTo-ToolkitExecutionBoolean $environment.IsAdministrator) -or
            -not (ConvertTo-ToolkitExecutionBoolean $environment.RestorePointReady) -or
            -not (Test-ToolkitExecutionStringEquals $environment.RestorePointCapability "Available")
        ) {
            throw "Administrator privileges and restore-point readiness are required for rollback."
        }
        if (
            -not (Test-ToolkitExecutionStringEquals $PreflightResult.PreflightId $expectedPreflight.PreflightId) -or
            -not (Test-ToolkitExecutionStringEquals $PreflightResult.Status $expectedPreflight.Status) -or
            -not (ConvertTo-ToolkitExecutionBoolean $PreflightResult.IsEligible) -or
            -not (Test-ToolkitExecutionStringEquals $PreflightResult.SafetyPolicyResult "Allowed")
        ) {
            throw "The preflight result is stale, altered, or ineligible."
        }
        if (
            -not (Test-ToolkitExecutionStringEquals $RollbackManifest.ManifestId $expectedManifest.ManifestId) -or
            -not (Test-ToolkitExecutionStringEquals $RollbackManifest.BeforeStateHash $expectedManifest.BeforeStateHash) -or
            [string]$RollbackManifest.BeforeStateSnapshot -cne
                [string]$expectedManifest.BeforeStateSnapshot -or
            -not (ConvertTo-ToolkitExecutionBoolean $RollbackManifest.BeforeStateCaptured) -or
            -not (ConvertTo-ToolkitExecutionBoolean $RollbackManifest.IsReversible)
        ) {
            throw "The rollback manifest or before-state hash is invalid."
        }
        if (
            -not (Test-ToolkitRollbackExecutionRecord `
                -ExecutionResult $ExecutionResult `
                -PlanEntry $PlanEntry `
                -PreflightResult $PreflightResult `
                -RollbackManifest $RollbackManifest `
                -ExecutionPolicy $policy)
        ) {
            throw "The execution audit does not prove an approved mutation attempt for these exact artifacts."
        }

        $currentObject = Get-ToolkitExecutorCurrentObject `
            -PlanEntry $PlanEntry `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy
        if (
            -not (Test-ToolkitExecutorServiceSafetyMetadataMatch `
                -CurrentObject $currentObject `
                -ReferenceObject $beforeState `
                -ExecutionPolicy $policy)
        ) {
            throw "Live service identity or safety metadata drifted from the rollback manifest."
        }
        if (
            [string]$currentObject.State -notin @("Running", "Stopped") -or
            [string]$currentObject.StartupType -notin @("Automatic", "Disabled")
        ) {
            throw "The current service state is outside the safely reversible state set."
        }
        $approvedRollbackState = [string]$currentObject.State
        $approvedRollbackStartupType = [string]$currentObject.StartupType
    }
    catch {
        $valid = $false
        $reason = $_.Exception.Message
        $remediation = "Do not retry rollback until the exact artifacts and live service state are reviewed."
    }

    if ($valid) {
        $gate = [PSCustomObject]@{
            Allowed           = $true
            DecisionCode      = "RollbackReady"
            PolicyAllowed     = $true
            PreflightValid    = $true
            ManifestValid     = $true
            CurrentStateValid = $true
            ExecutionPolicy   = $policy
            Reason            = "All exact-service rollback gates are satisfied."
            Remediation       = ""
        }
    }

    if (-not $valid) {
        return New-ToolkitExecutionAuditRecord `
            -PlanEntry $PlanEntry `
            -PreflightResult $PreflightResult `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy `
            -Gate $gate `
            -AttemptMode "Rollback" `
            -Status "Denied" `
            -DecisionCode "RollbackValidationFailed" `
            -Applied $false `
            -MutationAttempted $false `
            -ShouldProcessApproved $false `
            -ConfirmationProvided ([bool]$Confirmed) `
            -RollbackRequired $true `
            -RollbackStatus "Required - Not Executed" `
            -Reason $reason `
            -Remediation $remediation
    }

    if (
        Test-ToolkitExecutorBeforeStateMatch `
            -CurrentObject $currentObject `
            -PlanEntry $PlanEntry `
            -BeforeState $beforeState `
            -ExecutionPolicy $policy
    ) {
        return New-ToolkitExecutionAuditRecord `
            -PlanEntry $PlanEntry `
            -PreflightResult $PreflightResult `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy `
            -Gate $gate `
            -AttemptMode "Rollback" `
            -Status "Denied" `
            -DecisionCode "RollbackNotRequired" `
            -Applied $false `
            -MutationAttempted $false `
            -ShouldProcessApproved $false `
            -ConfirmationProvided ([bool]$Confirmed) `
            -RollbackRequired $false `
            -RollbackStatus "Not Required" `
            -Reason "The exact captured before-state is already present." `
            -Remediation "No rollback action is required."
    }

    if (-not $Apply) {
        return New-ToolkitExecutionAuditRecord `
            -PlanEntry $PlanEntry `
            -PreflightResult $PreflightResult `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy `
            -Gate $gate `
            -AttemptMode "Rollback" `
            -Status "Preview" `
            -DecisionCode "RollbackApplyRequired" `
            -Applied $false `
            -MutationAttempted $false `
            -ShouldProcessApproved $false `
            -ConfirmationProvided ([bool]$Confirmed) `
            -RollbackRequired $true `
            -RollbackStatus "Available" `
            -Reason "Rollback preview only; -Apply was not specified." `
            -Remediation "Review the exact before-state and use explicit Apply and confirmation only when ready."
    }

    if (-not $Confirmed) {
        return New-ToolkitExecutionAuditRecord `
            -PlanEntry $PlanEntry `
            -PreflightResult $PreflightResult `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy `
            -Gate $gate `
            -AttemptMode "Rollback" `
            -Status "Denied" `
            -DecisionCode "RollbackConfirmationMissing" `
            -Applied $false `
            -MutationAttempted $false `
            -ShouldProcessApproved $false `
            -ConfirmationProvided $false `
            -RollbackRequired $true `
            -RollbackStatus "Available" `
            -Reason "Rollback Apply was requested without explicit confirmation." `
            -Remediation "Review the manifest and provide explicit confirmation before retrying."
    }

    $approved = $PSCmdlet.ShouldProcess(
        "$($policy.ServiceName) ($($policy.ServiceDisplayName))",
        "Restore exact captured service configuration"
    )
    if (-not $approved) {
        return New-ToolkitExecutionAuditRecord `
            -PlanEntry $PlanEntry `
            -PreflightResult $PreflightResult `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy `
            -Gate $gate `
            -AttemptMode "Rollback" `
            -Status $(if ($WhatIfPreference) { "WhatIf" } else { "Declined" }) `
            -DecisionCode $(if ($WhatIfPreference) {
                "RollbackWhatIfPreview"
            } else {
                "RollbackShouldProcessDeclined"
            }) `
            -Applied $false `
            -MutationAttempted $false `
            -ShouldProcessApproved $false `
            -ConfirmationProvided $true `
            -RollbackRequired $true `
            -RollbackStatus "Available" `
            -Reason "PowerShell ShouldProcess did not approve rollback." `
            -Remediation "Review WhatIf output or rerun and approve the confirmation prompt."
    }

    try {
        $finalCurrentObject = Get-ToolkitExecutorCurrentObject `
            -PlanEntry $PlanEntry `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy
        if (
            -not (Test-ToolkitExecutorServiceSafetyMetadataMatch `
                -CurrentObject $finalCurrentObject `
                -ReferenceObject $beforeState `
                -ExecutionPolicy $policy) -or
            -not (Test-ToolkitExecutionStringEquals `
                $finalCurrentObject.State `
                $approvedRollbackState) -or
            -not (Test-ToolkitExecutionStringEquals `
                $finalCurrentObject.StartupType `
                $approvedRollbackStartupType)
        ) {
            throw "Final live-state validation failed after confirmation."
        }

        $contract = Get-ToolkitOptimizationServiceExecutorContract
        if (
            -not (Test-ToolkitExecutionStringEquals $RollbackManifest.TargetIdentity $contract.ServiceName) -or
            -not (Test-ToolkitExecutionStringEquals $beforeState.ServiceName $contract.ServiceName) -or
            -not (Test-ToolkitExecutionStringEquals $beforeState.ServiceDisplayName $contract.ServiceDisplayName) -or
            -not (Test-ToolkitExecutionStringEquals $beforeState.StartupType "Automatic") -or
            -not (Test-ToolkitExecutionStringEquals $beforeState.CurrentState "Running")
        ) {
            throw "Rollback only accepts the fixed captured HP Insights Analytics before-state."
        }

        $recovery = [string]$beforeState.RecoveryConfiguration |
            ConvertFrom-Json -ErrorAction Stop
        $delayedAutoStart = [string]$beforeState.DelayedAutoStartConfiguration |
            ConvertFrom-Json -ErrorAction Stop
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($contract.ServiceName)"

        $rollbackMutationAttempted = $true
        Set-Service `
            -Name $contract.ServiceName `
            -StartupType Automatic `
            -ErrorAction Stop
        if ($recovery.FailureActionsPresent) {
            New-ItemProperty `
                -LiteralPath $registryPath `
                -Name "FailureActions" `
                -Value ([Convert]::FromBase64String(
                    [string]$recovery.FailureActionsBase64
                )) `
                -PropertyType Binary `
                -Force `
                -ErrorAction Stop
        }
        else {
            Remove-ItemProperty `
                -LiteralPath $registryPath `
                -Name "FailureActions" `
                -ErrorAction SilentlyContinue
        }
        if ($recovery.FailureActionsOnNonCrashFailuresPresent) {
            New-ItemProperty `
                -LiteralPath $registryPath `
                -Name "FailureActionsOnNonCrashFailures" `
                -Value ([int]$recovery.FailureActionsOnNonCrashFailures) `
                -PropertyType DWord `
                -Force `
                -ErrorAction Stop
        }
        else {
            Remove-ItemProperty `
                -LiteralPath $registryPath `
                -Name "FailureActionsOnNonCrashFailures" `
                -ErrorAction SilentlyContinue
        }
        if ($recovery.FailureCommandPresent) {
            New-ItemProperty `
                -LiteralPath $registryPath `
                -Name "FailureCommand" `
                -Value ([string]$recovery.FailureCommand) `
                -PropertyType String `
                -Force `
                -ErrorAction Stop
        }
        else {
            Remove-ItemProperty `
                -LiteralPath $registryPath `
                -Name "FailureCommand" `
                -ErrorAction SilentlyContinue
        }
        if ($recovery.RebootMessagePresent) {
            New-ItemProperty `
                -LiteralPath $registryPath `
                -Name "RebootMessage" `
                -Value ([string]$recovery.RebootMessage) `
                -PropertyType String `
                -Force `
                -ErrorAction Stop
        }
        else {
            Remove-ItemProperty `
                -LiteralPath $registryPath `
                -Name "RebootMessage" `
                -ErrorAction SilentlyContinue
        }
        if ($delayedAutoStart.Present) {
            New-ItemProperty `
                -LiteralPath $registryPath `
                -Name "DelayedAutoStart" `
                -Value ([int]$delayedAutoStart.Value) `
                -PropertyType DWord `
                -Force `
                -ErrorAction Stop
        }
        else {
            Remove-ItemProperty `
                -LiteralPath $registryPath `
                -Name "DelayedAutoStart" `
                -ErrorAction SilentlyContinue
        }
        Start-Service `
            -Name $contract.ServiceName `
            -ErrorAction Stop
        $postObject = Get-ToolkitExecutorCurrentObject `
            -PlanEntry $PlanEntry `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy
        $observedState = Get-ToolkitExecutorObservedState `
            -CurrentObject $postObject `
            -ExecutionPolicy $policy

        if (
            -not (Test-ToolkitExecutorBeforeStateMatch `
                -CurrentObject $postObject `
                -PlanEntry $PlanEntry `
                -BeforeState $beforeState `
                -ExecutionPolicy $policy)
        ) {
            throw "Rollback returned without restoring the exact captured before-state."
        }

        return New-ToolkitExecutionAuditRecord `
            -PlanEntry $PlanEntry `
            -PreflightResult $PreflightResult `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy `
            -Gate $gate `
            -AttemptMode "Rollback" `
            -Status "RolledBack" `
            -DecisionCode "RollbackExecuted" `
            -Applied $true `
            -MutationAttempted $true `
            -ShouldProcessApproved $true `
            -ConfirmationProvided $true `
            -ObservedStateAfter $observedState `
            -RollbackRequired $false `
            -RollbackStatus "Completed" `
            -Reason "The exact captured service before-state was restored and verified." `
            -Remediation "Retain the rollback audit record."
    }
    catch {
        $observedState = ""
        try {
            $failureObject = Get-ToolkitExecutorCurrentObject `
                -PlanEntry $PlanEntry `
                -RollbackManifest $RollbackManifest `
                -ExecutionPolicy $policy
            $observedState = Get-ToolkitExecutorObservedState `
                -CurrentObject $failureObject `
                -ExecutionPolicy $policy
        }
        catch {
            $observedState = ""
        }

        return New-ToolkitExecutionAuditRecord `
            -PlanEntry $PlanEntry `
            -PreflightResult $PreflightResult `
            -RollbackManifest $RollbackManifest `
            -ExecutionPolicy $policy `
            -Gate $gate `
            -AttemptMode "Rollback" `
            -Status "Indeterminate" `
            -DecisionCode "RollbackOutcomeIndeterminate" `
            -Applied $false `
            -MutationAttempted $rollbackMutationAttempted `
            -ShouldProcessApproved $true `
            -ConfirmationProvided $true `
            -ObservedStateAfter $observedState `
            -RollbackRequired $true `
            -RollbackStatus "Failed - Review Required" `
            -Reason "Rollback failed or could not be verified: $($_.Exception.Message)" `
            -Remediation "Treat the service state as indeterminate and perform a manual exact-state review."
    }
}

function Invoke-ToolkitOptimizationExecutor {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [AllowEmptyCollection()][object[]]$PlanEntries,
        [AllowEmptyCollection()][object[]]$PreflightResults,
        [AllowEmptyCollection()][object[]]$RollbackManifest,
        [switch]$Apply,
        [switch]$Confirmed
    )

    $attemptMode = if ($Apply) { "Apply" } else { "DryRun" }
    $seenActions = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $results = foreach ($planEntry in @($PlanEntries)) {
        if ($null -eq $planEntry) {
            continue
        }

        $actionKey = "$($planEntry.PlanId)|$($planEntry.ActionId)"
        if (-not $seenActions.Add($actionKey)) {
            $duplicateGate = New-ToolkitDeniedExecutionGate `
                -DecisionCode "DuplicatePlanAction" `
                -Reason "The same plan action appears more than once in the execution request." `
                -Remediation "Remove duplicate entries and regenerate the reports."
            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $null `
                -RollbackManifest $null `
                -ExecutionPolicy $null `
                -Gate $duplicateGate `
                -AttemptMode $attemptMode `
                -Status "Denied" `
                -DecisionCode $duplicateGate.DecisionCode `
                -Applied $false `
                -MutationAttempted $false `
                -ShouldProcessApproved $false `
                -ConfirmationProvided ([bool]$Confirmed) `
                -RollbackRequired $false `
                -RollbackStatus "Not Required" `
                -Reason $duplicateGate.Reason `
                -Remediation $duplicateGate.Remediation
            continue
        }

        $preflightMatches = @(
            $PreflightResults |
                Where-Object {
                    (Test-ToolkitExecutionStringEquals $_.PlanId $planEntry.PlanId) -and
                    (Test-ToolkitExecutionStringEquals $_.ActionId $planEntry.ActionId)
                }
        )
        $manifestMatches = @(
            $RollbackManifest |
                Where-Object {
                    (Test-ToolkitExecutionStringEquals $_.PlanId $planEntry.PlanId) -and
                    (Test-ToolkitExecutionStringEquals $_.ActionId $planEntry.ActionId)
                }
        )

        if ($preflightMatches.Count -gt 1 -or $manifestMatches.Count -gt 1) {
            $ambiguousGate = New-ToolkitDeniedExecutionGate `
                -DecisionCode "AmbiguousExecutionArtifacts" `
                -Reason "Multiple preflight or rollback records match the same plan action." `
                -Remediation "Discard the ambiguous reports and regenerate the optimizer artifacts."
            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult ($preflightMatches | Select-Object -First 1) `
                -RollbackManifest ($manifestMatches | Select-Object -First 1) `
                -ExecutionPolicy $null `
                -Gate $ambiguousGate `
                -AttemptMode $attemptMode `
                -Status "Denied" `
                -DecisionCode $ambiguousGate.DecisionCode `
                -Applied $false `
                -MutationAttempted $false `
                -ShouldProcessApproved $false `
                -ConfirmationProvided ([bool]$Confirmed) `
                -RollbackRequired $false `
                -RollbackStatus "Not Required" `
                -Reason $ambiguousGate.Reason `
                -Remediation $ambiguousGate.Remediation
            continue
        }

        $preflightResult = $preflightMatches | Select-Object -First 1
        $manifestEntry = $manifestMatches | Select-Object -First 1
        $rules = Get-ToolkitOptimizationActionRules
        $environment = Get-ToolkitPreflightEnvironment
        $gate = Test-ToolkitOptimizationExecutionGate `
            -PlanEntry $planEntry `
            -PreflightResult $preflightResult `
            -RollbackManifest $manifestEntry `
            -Rules $rules `
            -Environment $environment
        $policy = $gate.ExecutionPolicy

        if (-not $gate.Allowed) {
            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $preflightResult `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $policy `
                -Gate $gate `
                -AttemptMode $attemptMode `
                -Status "Denied" `
                -DecisionCode $gate.DecisionCode `
                -Applied $false `
                -MutationAttempted $false `
                -ShouldProcessApproved $false `
                -ConfirmationProvided ([bool]$Confirmed) `
                -RollbackRequired $false `
                -RollbackStatus "Not Required" `
                -Reason $gate.Reason `
                -Remediation $gate.Remediation
            continue
        }

        if (-not $Apply) {
            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $preflightResult `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $policy `
                -Gate $gate `
                -AttemptMode $attemptMode `
                -Status "Preview" `
                -DecisionCode "ApplyRequired" `
                -Applied $false `
                -MutationAttempted $false `
                -ShouldProcessApproved $false `
                -ConfirmationProvided ([bool]$Confirmed) `
                -RollbackRequired $false `
                -RollbackStatus "Not Required" `
                -Reason "Dry-run preview only; -Apply was not specified." `
                -Remediation "Review the audit record and use explicit Apply and confirmation only when ready."
            continue
        }

        if (-not $Confirmed) {
            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $preflightResult `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $policy `
                -Gate $gate `
                -AttemptMode $attemptMode `
                -Status "Denied" `
                -DecisionCode "ConfirmationMissing" `
                -Applied $false `
                -MutationAttempted $false `
                -ShouldProcessApproved $false `
                -ConfirmationProvided $false `
                -RollbackRequired $false `
                -RollbackStatus "Not Required" `
                -Reason "Apply was requested without explicit executor confirmation." `
                -Remediation "Review the plan and provide explicit confirmation before retrying."
            continue
        }

        $target = if (
            Test-ToolkitExecutionStringEquals $policy.ExecutorId "DisableService"
        ) {
            "$($planEntry.ServiceName) ($($planEntry.ServiceDisplayName))"
        }
        else {
            "$($planEntry.Source)$($planEntry.SourceName)"
        }
        $action = "$($policy.ExecutorId) -> $($policy.TargetState)"
        $shouldProcessApproved = $PSCmdlet.ShouldProcess($target, $action)

        if (-not $shouldProcessApproved) {
            $status = if ($WhatIfPreference) { "WhatIf" } else { "Declined" }
            $decisionCode = if ($WhatIfPreference) {
                "WhatIfPreview"
            }
            else {
                "ShouldProcessDeclined"
            }

            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $preflightResult `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $policy `
                -Gate $gate `
                -AttemptMode $attemptMode `
                -Status $status `
                -DecisionCode $decisionCode `
                -Applied $false `
                -MutationAttempted $false `
                -ShouldProcessApproved $false `
                -ConfirmationProvided $true `
                -RollbackRequired $false `
                -RollbackStatus "Not Required" `
                -Reason "PowerShell ShouldProcess did not approve the operation." `
                -Remediation "Review WhatIf output or rerun and approve the confirmation prompt."
            continue
        }

        $finalRules = Get-ToolkitOptimizationActionRules
        $finalEnvironment = Get-ToolkitPreflightEnvironment
        $finalGate = Test-ToolkitOptimizationExecutionGate `
            -PlanEntry $planEntry `
            -PreflightResult $preflightResult `
            -RollbackManifest $manifestEntry `
            -Rules $finalRules `
            -Environment $finalEnvironment

        if (-not $finalGate.Allowed) {
            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $preflightResult `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $finalGate.ExecutionPolicy `
                -Gate $finalGate `
                -AttemptMode $attemptMode `
                -Status "Denied" `
                -DecisionCode "FinalValidationFailed" `
                -Applied $false `
                -MutationAttempted $false `
                -ShouldProcessApproved $true `
                -ConfirmationProvided $true `
                -RollbackRequired $false `
                -RollbackStatus "Not Required" `
                -Reason "Final validation failed after confirmation: $($finalGate.DecisionCode). $($finalGate.Reason)" `
                -Remediation "Do not retry until the drift or safety-policy failure is reviewed."
            continue
        }

        $policy = $finalGate.ExecutionPolicy
        $targetIdentity = [string]$manifestEntry.TargetIdentity
        $taskPath = [string]$planEntry.Source
        $approvedBeforeState = [string]$manifestEntry.BeforeStateSnapshot |
            ConvertFrom-Json -ErrorAction Stop
        $executionMutationAttempted = $false
        try {
            switch ([string]$policy.ExecutorId) {
                "DisableScheduledTask" {
                    $executionMutationAttempted = $true
                    Disable-ScheduledTask `
                        -TaskName $targetIdentity `
                        -TaskPath $taskPath `
                        -ErrorAction Stop |
                        Out-Null
                }

                "DisableService" {
                    $contract = Get-ToolkitOptimizationServiceExecutorContract
                    if (
                        -not (Test-ToolkitExecutionStringEquals $targetIdentity $contract.ServiceName) -or
                        -not (Test-ToolkitOptimizationLiteralServiceIdentity $targetIdentity)
                    ) {
                        throw "The service executor only accepts the fixed HP Insights Analytics service identity."
                    }

                    $executionMutationAttempted = $true
                    Stop-Service `
                        -Name $contract.ServiceName `
                        -ErrorAction Stop
                    Set-Service `
                        -Name $contract.ServiceName `
                        -StartupType Disabled `
                        -ErrorAction Stop
                }

                default {
                    throw "Unsupported executor."
                }
            }

            try {
                $postObject = Get-ToolkitExecutorCurrentObject `
                    -PlanEntry $planEntry `
                    -RollbackManifest $manifestEntry `
                    -ExecutionPolicy $policy
                $observedState = Get-ToolkitExecutorObservedState `
                    -CurrentObject $postObject `
                    -ExecutionPolicy $policy
            }
            catch {
                $observedState = ""
                throw "The operation returned, but post-state validation failed: $($_.Exception.Message)"
            }

            if (-not (Test-ToolkitExecutorTargetState `
                -CurrentObject $postObject `
                -ExecutionPolicy $policy `
                -BeforeState $approvedBeforeState)) {
                $rollbackRequired = -not (Test-ToolkitExecutorBeforeStateMatch `
                    -CurrentObject $postObject `
                    -PlanEntry $planEntry `
                    -BeforeState $approvedBeforeState `
                    -ExecutionPolicy $policy)
                New-ToolkitExecutionAuditRecord `
                    -PlanEntry $planEntry `
                    -PreflightResult $preflightResult `
                    -RollbackManifest $manifestEntry `
                    -ExecutionPolicy $policy `
                    -Gate $finalGate `
                    -AttemptMode $attemptMode `
                    -Status $(if ($rollbackRequired) { "Indeterminate" } else { "Failed" }) `
                    -DecisionCode "PostStateMismatch" `
                    -Applied $false `
                    -MutationAttempted $true `
                    -ShouldProcessApproved $true `
                    -ConfirmationProvided $true `
                    -ObservedStateAfter $observedState `
                    -RollbackRequired $rollbackRequired `
                    -RollbackStatus $(if ($rollbackRequired) { "Required - Not Executed" } else { "Not Required" }) `
                    -Reason "The operation returned without reaching the allowlisted target state." `
                    -Remediation "Review the live state and rollback manifest before any retry."
                continue
            }

            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $preflightResult `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $policy `
                -Gate $finalGate `
                -AttemptMode $attemptMode `
                -Status "Executed" `
                -DecisionCode "Executed" `
                -Applied $true `
                -MutationAttempted $true `
                -ShouldProcessApproved $true `
                -ConfirmationProvided $true `
                -ObservedStateAfter $observedState `
                -RollbackRequired $false `
                -RollbackStatus "Available" `
                -Reason "The allowlisted operation completed and the target state was verified." `
                -Remediation "Retain the rollback manifest and execution audit record."
        }
        catch {
            $executionError = $_.Exception.Message
            $observedState = ""
            $applied = $false
            $rollbackRequired = $true
            $status = "Indeterminate"
            $decisionCode = "ExecutionOutcomeIndeterminate"

            try {
                $failureObject = Get-ToolkitExecutorCurrentObject `
                    -PlanEntry $planEntry `
                    -RollbackManifest $manifestEntry `
                    -ExecutionPolicy $policy
                $observedState = Get-ToolkitExecutorObservedState `
                    -CurrentObject $failureObject `
                    -ExecutionPolicy $policy

                if (Test-ToolkitExecutorTargetState `
                    -CurrentObject $failureObject `
                    -ExecutionPolicy $policy `
                    -BeforeState $approvedBeforeState) {
                    $applied = $true
                    $status = "FailedAfterStateChange"
                    $decisionCode = "ExecutionFailedAfterStateChange"
                }
                elseif (Test-ToolkitExecutorBeforeStateMatch `
                    -CurrentObject $failureObject `
                    -PlanEntry $planEntry `
                    -BeforeState $approvedBeforeState `
                    -ExecutionPolicy $policy) {
                    $rollbackRequired = $false
                    $status = "Failed"
                    $decisionCode = "ExecutionFailedNoStateChange"
                }
            }
            catch {
                $executionError = "$executionError Post-failure state validation also failed: $($_.Exception.Message)"
            }

            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $preflightResult `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $policy `
                -Gate $finalGate `
                -AttemptMode $attemptMode `
                -Status $status `
                -DecisionCode $decisionCode `
                -Applied $applied `
                -MutationAttempted $executionMutationAttempted `
                -ShouldProcessApproved $true `
                -ConfirmationProvided $true `
                -ObservedStateAfter $observedState `
                -RollbackRequired $rollbackRequired `
                -RollbackStatus $(if ($rollbackRequired) { "Required - Not Executed" } else { "Not Required" }) `
                -Reason "Execution failed: $executionError" `
                -Remediation $(if ($rollbackRequired) {
                    "Treat the outcome as changed or unknown and review the rollback manifest before any retry."
                } else {
                    "The before-state was verified; review the failure before retrying."
                })
        }
    }

    return @($results)
}

Export-ModuleMember -Function @(
    "Invoke-ToolkitOptimizationExecutor",
    "Invoke-ToolkitOptimizationRollback"
)

Import-Module (Join-Path $PSScriptRoot "Models.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Optimizer.psm1") -Force

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

function Get-ToolkitOptimizationExecutionPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [object]$Rules = (Get-ToolkitOptimizationActionRules)
    )

    $actionId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ActionId"
    $sourceType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType"
    $vendor = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Vendor"
    $reportFile = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ReportFile"
    $currentState = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "CurrentState"
    $operationType = Get-ToolkitFindingPropertyValue `
        -Finding $RollbackManifest `
        -Name "OperationType"

    foreach ($policy in @($Rules.executionPolicies)) {
        $actionMatches = [string]::Equals(
            $actionId,
            [string]$policy.actionId,
            [System.StringComparison]::OrdinalIgnoreCase
        )
        $operationMatches = [string]::Equals(
            $operationType,
            [string]$policy.operationType,
            [System.StringComparison]::OrdinalIgnoreCase
        )
        $sourceTypeMatches = @(
            $policy.sourceTypes |
                Where-Object {
                    [string]::Equals(
                        $sourceType,
                        [string]$_,
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                }
        ).Count -gt 0
        $vendorMatches = @(
            $policy.allowedVendors |
                Where-Object {
                    [string]::Equals(
                        $vendor,
                        [string]$_,
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                }
        ).Count -gt 0
        $reportFileMatches = @(
            $policy.allowedReportFiles |
                Where-Object {
                    [string]::Equals(
                        $reportFile,
                        [string]$_,
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                }
        ).Count -gt 0
        $currentStateMatches = @(
            $policy.allowedCurrentStates |
                Where-Object {
                    [string]::Equals(
                        $currentState,
                        [string]$_,
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                }
        ).Count -gt 0

        if (
            $actionMatches -and
            $operationMatches -and
            $sourceTypeMatches -and
            $vendorMatches -and
            $reportFileMatches -and
            $currentStateMatches
        ) {
            return $policy
        }
    }

    return $null
}

function Get-ToolkitExecutorCurrentState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    switch ([string]$ExecutionPolicy.executorId) {
        "DisableScheduledTask" {
            $task = Get-ScheduledTask `
                -TaskName ([string]$RollbackManifest.TargetIdentity) `
                -TaskPath ([string]$PlanEntry.Source) `
                -ErrorAction Stop

            if ($null -eq $task) {
                throw "Scheduled task was not found."
            }

            return [string]$task.State
        }

        default {
            throw "Unsupported executor: $($ExecutionPolicy.executorId)"
        }
    }
}

function Test-ToolkitOptimizationExecutionGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [AllowNull()][object]$PreflightResult,
        [AllowNull()][object]$RollbackManifest,
        [object]$Rules = (Get-ToolkitOptimizationActionRules),
        [object]$Environment = (Get-ToolkitPreflightEnvironment)
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

    if (Test-ToolkitProtectedFinding -Finding $PlanEntry -Rules $Rules) {
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
    else {
        $expectedPreflightId = Get-ToolkitStableId `
            -Prefix "PF" `
            -Parts @($planId, $sourceFindingId, $actionId)
        $currentPreflight = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry $PlanEntry `
            -Rules $Rules `
            -Environment $Environment
        $preflightIdentityValid = (
            [string]$PreflightResult.PreflightId -eq $expectedPreflightId -and
            [string]$PreflightResult.PlanId -eq $planId -and
            [string]$PreflightResult.SourceFindingId -eq $sourceFindingId -and
            [string]$PreflightResult.ActionId -eq $actionId
        )
        $preflightStateValid = (
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.IsEligible) -and
            -not (ConvertTo-ToolkitExecutionBoolean $PreflightResult.IsBlocked) -and
            [string]$PreflightResult.EligibilityStatus -eq "Eligible" -and
            [string]$PreflightResult.Status -eq "Confirmation Required" -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.ConfirmationRequired) -and
            [string]$PreflightResult.CurrentStateValidationResult -eq "Valid" -and
            [string]$PreflightResult.SafetyPolicyResult -eq "Allowed" -and
            [string]$PreflightResult.ReversibilityStatus -eq "Reversible" -and
            [string]$PreflightResult.Status -eq [string]$currentPreflight.Status -and
            [string]$PreflightResult.EligibilityStatus -eq [string]$currentPreflight.EligibilityStatus -and
            [string]$PreflightResult.CurrentStateValidationResult -eq [string]$currentPreflight.CurrentStateValidationResult -and
            [string]$PreflightResult.SafetyPolicyResult -eq [string]$currentPreflight.SafetyPolicyResult -and
            [string]$PreflightResult.ReversibilityStatus -eq [string]$currentPreflight.ReversibilityStatus -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.IsEligible) -eq
                (ConvertTo-ToolkitExecutionBoolean $currentPreflight.IsEligible) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.IsBlocked) -eq
                (ConvertTo-ToolkitExecutionBoolean $currentPreflight.IsBlocked) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.AdministratorReady) -eq
                (ConvertTo-ToolkitExecutionBoolean $currentPreflight.AdministratorReady) -and
            (ConvertTo-ToolkitExecutionBoolean $PreflightResult.RestorePointReady) -eq
                (ConvertTo-ToolkitExecutionBoolean $currentPreflight.RestorePointReady)
        )
        $preflightValid = (
            $preflightIdentityValid -and
            $preflightStateValid
        )

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
                [string]$RollbackManifest.PlanId -eq $planId -and
                [string]$RollbackManifest.SourceFindingId -eq $sourceFindingId -and
                [string]$RollbackManifest.ActionId -eq $actionId -and
                [string]$RollbackManifest.PreflightId -eq [string]$PreflightResult.PreflightId -and
                [string]$RollbackManifest.BeforeStateHash -eq $expectedBeforeStateHash -and
                (ConvertTo-ToolkitExecutionBoolean $RollbackManifest.BeforeStateCaptured) -and
                (ConvertTo-ToolkitExecutionBoolean $RollbackManifest.IsReversible) -and
                [string]$RollbackManifest.SafetyPolicyResult -eq "Allowed" -and
                [string]$RollbackManifest.ManifestId -eq [string]$expectedManifest.ManifestId -and
                [string]$RollbackManifest.OperationType -eq [string]$expectedManifest.OperationType -and
                [string]$RollbackManifest.TargetIdentity -eq [string]$expectedManifest.TargetIdentity -and
                [string]$RollbackManifest.BeforeStateSnapshot -eq [string]$expectedManifest.BeforeStateSnapshot -and
                [string]$RollbackManifest.BeforeStateHash -eq [string]$expectedManifest.BeforeStateHash -and
                [string]$RollbackManifest.RequiredBeforeStateFields -eq [string]$expectedManifest.RequiredBeforeStateFields -and
                [string]$RollbackManifest.MissingBeforeStateFields -eq [string]$expectedManifest.MissingBeforeStateFields
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
                    $reasons.Add([string]$Rules.executionDefaultDenyReason)
                    $remediation.Add("No execution is permitted until a specific JSON policy safely allowlists this operation.")
                }
                else {
                    try {
                        $beforeState = [string]$RollbackManifest.BeforeStateSnapshot |
                            ConvertFrom-Json `
                                -ErrorAction Stop
                        $observedState = Get-ToolkitExecutorCurrentState `
                            -PlanEntry $PlanEntry `
                            -RollbackManifest $RollbackManifest `
                            -ExecutionPolicy $executionPolicy
                        $currentStateValid = (
                            [string]::Equals(
                                [string]$observedState,
                                [string]$PlanEntry.CurrentState,
                                [System.StringComparison]::OrdinalIgnoreCase
                            ) -and
                            [string]::Equals(
                                [string]$observedState,
                                [string]$beforeState.CurrentState,
                                [System.StringComparison]::OrdinalIgnoreCase
                            )
                        )
                    }
                    catch {
                        $currentStateValid = $false
                        $reasons.Add("Current state could not be read: $($_.Exception.Message)")
                    }

                    if (-not $currentStateValid) {
                        $decisionCode = "StaleCurrentState"
                        $reasons.Add("The live current state no longer matches the plan and rollback before-state snapshot.")
                        $remediation.Add("Regenerate the plan, preflight result, and rollback manifest before applying.")
                    }
                    elseif ([string]::Equals(
                        [string]$observedState,
                        [string]$executionPolicy.targetState,
                        [System.StringComparison]::OrdinalIgnoreCase
                    )) {
                        $currentStateValid = $false
                        $decisionCode = "AlreadyAtTargetState"
                        $reasons.Add("The live object is already in the execution policy target state.")
                        $remediation.Add("No action is required; regenerate reports if the plan still proposes this change.")
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

function Invoke-ToolkitAllowedExecutionOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    switch ([string]$ExecutionPolicy.executorId) {
        "DisableScheduledTask" {
            Disable-ScheduledTask `
                -TaskName ([string]$RollbackManifest.TargetIdentity) `
                -TaskPath ([string]$PlanEntry.Source) `
                -ErrorAction Stop |
                Out-Null
        }

        default {
            throw "Unsupported executor: $($ExecutionPolicy.executorId)"
        }
    }
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
        [Parameter(Mandatory)][bool]$ShouldProcessApproved,
        [Parameter(Mandatory)][bool]$ConfirmationProvided,
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$Remediation
    )

    $attemptedAtUtc = [datetime]::UtcNow
    $executionId = Get-ToolkitStableId `
        -Prefix "EX" `
        -Parts @(
            [string]$PlanEntry.PlanId,
            [string]$PlanEntry.ActionId,
            [string]$RollbackManifest.ManifestId,
            $AttemptMode,
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
        -PlanId ([string]$PlanEntry.PlanId) `
        -PreflightId ([string]$PreflightResult.PreflightId) `
        -ManifestId ([string]$RollbackManifest.ManifestId) `
        -ActionId ([string]$PlanEntry.ActionId) `
        -SourceFinding ([string]$PlanEntry.SourceFinding) `
        -SourceName ([string]$PlanEntry.SourceName) `
        -SourceType ([string]$PlanEntry.SourceType) `
        -OperationType $operationType `
        -ExecutorId ([string]$ExecutionPolicy.executorId) `
        -AttemptMode $AttemptMode `
        -Status $Status `
        -DecisionCode $DecisionCode `
        -Applied $Applied `
        -ShouldProcessApproved $ShouldProcessApproved `
        -PolicyAllowed ([bool]$Gate.PolicyAllowed) `
        -PreflightValid ([bool]$Gate.PreflightValid) `
        -ManifestValid ([bool]$Gate.ManifestValid) `
        -CurrentStateValid ([bool]$Gate.CurrentStateValid) `
        -ConfirmationProvided $ConfirmationProvided `
        -Reason $Reason `
        -Remediation $Remediation `
        -BeforeStateHash ([string]$RollbackManifest.BeforeStateHash) `
        -RollbackOperationType ([string]$ExecutionPolicy.rollbackOperationType) `
        -RollbackTargetState ([string]$ExecutionPolicy.rollbackTargetState) `
        -AttemptedAtUtc $attemptedAtUtc
}

function Invoke-ToolkitOptimizationExecutor {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [AllowEmptyCollection()][object[]]$PlanEntries,
        [AllowEmptyCollection()][object[]]$PreflightResults,
        [AllowEmptyCollection()][object[]]$RollbackManifest,
        [switch]$Apply,
        [switch]$Confirmed,
        [object]$Rules = (Get-ToolkitOptimizationActionRules),
        [object]$Environment = (Get-ToolkitPreflightEnvironment)
    )

    $attemptMode = if ($Apply) { "Apply" } else { "DryRun" }
    $results = foreach ($planEntry in @($PlanEntries)) {
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
        $manifestEntry = @(
            $RollbackManifest |
                Where-Object {
                    [string]$_.PlanId -eq [string]$planEntry.PlanId -and
                    [string]$_.ActionId -eq [string]$planEntry.ActionId
                }
        ) | Select-Object -First 1
        $gate = Test-ToolkitOptimizationExecutionGate `
            -PlanEntry $planEntry `
            -PreflightResult $preflightResult `
            -RollbackManifest $manifestEntry `
            -Rules $Rules `
            -Environment $Environment
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
                -ShouldProcessApproved $false `
                -ConfirmationProvided ([bool]$Confirmed) `
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
                -ShouldProcessApproved $false `
                -ConfirmationProvided ([bool]$Confirmed) `
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
                -ShouldProcessApproved $false `
                -ConfirmationProvided $false `
                -Reason "Apply was requested without explicit executor confirmation." `
                -Remediation "Review the plan and provide explicit confirmation before retrying."
            continue
        }

        $target = [string]$planEntry.SourceFinding
        $action = "$($policy.executorId) -> $($policy.targetState)"
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
                -ShouldProcessApproved $false `
                -ConfirmationProvided $true `
                -Reason "PowerShell ShouldProcess did not approve the operation." `
                -Remediation "Review WhatIf output or rerun and approve the confirmation prompt."
            continue
        }

        try {
            Invoke-ToolkitAllowedExecutionOperation `
                -PlanEntry $planEntry `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $policy

            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $preflightResult `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $policy `
                -Gate $gate `
                -AttemptMode $attemptMode `
                -Status "Executed" `
                -DecisionCode "Executed" `
                -Applied $true `
                -ShouldProcessApproved $true `
                -ConfirmationProvided $true `
                -Reason "The allowlisted operation completed successfully." `
                -Remediation "Retain the rollback manifest and execution audit record."
        }
        catch {
            New-ToolkitExecutionAuditRecord `
                -PlanEntry $planEntry `
                -PreflightResult $preflightResult `
                -RollbackManifest $manifestEntry `
                -ExecutionPolicy $policy `
                -Gate $gate `
                -AttemptMode $attemptMode `
                -Status "Failed" `
                -DecisionCode "ExecutionFailed" `
                -Applied $false `
                -ShouldProcessApproved $true `
                -ConfirmationProvided $true `
                -Reason "Execution failed: $($_.Exception.Message)" `
                -Remediation "Do not retry until the failure is reviewed against the rollback manifest."
        }
    }

    return @($results)
}

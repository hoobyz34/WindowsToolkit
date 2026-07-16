Import-Module (Join-Path $PSScriptRoot "Models.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Optimizer.psm1") -Force

$script:ExecutorContract = [PSCustomObject]@{
    PolicyId                  = "disable-hp-scheduled-task"
    ActionId                  = "review-likely-disable"
    OperationType             = "ScheduledTaskStateChange"
    SourceTypes               = @("Scheduled Task", "ScheduledTask")
    Vendor                    = "HP"
    ReportFile                = "ScheduledTasks_Report.csv"
    AllowedCurrentStates      = @("Ready", "Disabled")
    ExecutorId                = "DisableScheduledTask"
    TargetState               = "Disabled"
    MutatingCommand           = "Disable-ScheduledTask"
    RollbackOperationType     = "EnableScheduledTask"
    RollbackTargetState       = "Enabled"
    TaskPathPrefix            = "\HP\"
    TaskNamePatterns          = @(
        "HP Insights",
        "HP Analytics",
        "HP Touchpoint",
        "Telemetry"
    )
    TaskAuthorPatterns        = @(
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

function Test-ToolkitExecutionCollectionContains {
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$Values,
        [AllowNull()][object]$Expected
    )

    return @(
        @($Values) |
            Where-Object {
                Test-ToolkitExecutionStringEquals -Left $_ -Right $Expected
            }
    ).Count -gt 0
}

function Get-ToolkitConfiguredExecutionPatterns {
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$ConfiguredPatterns,
        [Parameter(Mandatory)][string[]]$MaximumPatterns
    )

    return @(
        foreach ($maximumPattern in $MaximumPatterns) {
            if (
                Test-ToolkitExecutionCollectionContains `
                    -Values $ConfiguredPatterns `
                    -Expected $maximumPattern
            ) {
                $maximumPattern
            }
        }
    )
}

function Get-ToolkitOptimizationExecutionPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$Rules
    )

    $contract = $script:ExecutorContract
    $actionId = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ActionId"
    $sourceType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType"
    $vendor = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Vendor"
    $reportFile = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ReportFile"
    $currentState = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "CurrentState"
    $operationType = Get-ToolkitFindingPropertyValue `
        -Finding $RollbackManifest `
        -Name "OperationType"

    foreach ($policy in @($Rules.executionPolicies)) {
        $namePatterns = Get-ToolkitConfiguredExecutionPatterns `
            -ConfiguredPatterns @($policy.allowedTaskNamePatterns) `
            -MaximumPatterns $contract.TaskNamePatterns
        $authorPatterns = Get-ToolkitConfiguredExecutionPatterns `
            -ConfiguredPatterns @($policy.allowedTaskAuthorPatterns) `
            -MaximumPatterns $contract.TaskAuthorPatterns
        $policyContractValid = (
            (Test-ToolkitExecutionStringEquals $policy.id $contract.PolicyId) -and
            (Test-ToolkitExecutionStringEquals $policy.actionId $contract.ActionId) -and
            (Test-ToolkitExecutionStringEquals $policy.operationType $contract.OperationType) -and
            (Test-ToolkitExecutionStringEquals $policy.executorId $contract.ExecutorId) -and
            (Test-ToolkitExecutionStringEquals $policy.targetState $contract.TargetState) -and
            (Test-ToolkitExecutionStringEquals $policy.mutatingCommand $contract.MutatingCommand) -and
            (Test-ToolkitExecutionStringEquals $policy.rollbackOperationType $contract.RollbackOperationType) -and
            (Test-ToolkitExecutionStringEquals $policy.rollbackTargetState $contract.RollbackTargetState) -and
            (Test-ToolkitExecutionCollectionContains $policy.allowedTaskPathPrefixes $contract.TaskPathPrefix) -and
            $namePatterns.Count -gt 0 -and
            $authorPatterns.Count -gt 0
        )
        $planMatchesPolicy = (
            (Test-ToolkitExecutionStringEquals $actionId $contract.ActionId) -and
            (Test-ToolkitExecutionStringEquals $operationType $contract.OperationType) -and
            (Test-ToolkitExecutionCollectionContains $contract.SourceTypes $sourceType) -and
            (Test-ToolkitExecutionCollectionContains $policy.sourceTypes $sourceType) -and
            (Test-ToolkitExecutionStringEquals $vendor $contract.Vendor) -and
            (Test-ToolkitExecutionCollectionContains $policy.allowedVendors $vendor) -and
            (Test-ToolkitExecutionStringEquals $reportFile $contract.ReportFile) -and
            (Test-ToolkitExecutionCollectionContains $policy.allowedReportFiles $reportFile) -and
            (Test-ToolkitExecutionCollectionContains $contract.AllowedCurrentStates $currentState) -and
            (Test-ToolkitExecutionCollectionContains $policy.allowedCurrentStates $currentState)
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

    return $null
}

function Test-ToolkitPermanentExecutorProtection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry
    )

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
        (Test-ToolkitExecutionStringEquals $category "Required") -or
        (Test-ToolkitExecutionStringEquals $risk "Critical") -or
        $source.StartsWith(
            "\Microsoft\",
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return $true
    }

    foreach ($protectedPattern in $script:ExecutorContract.PermanentProtectedPatterns) {
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

function Test-ToolkitExecutorLiteralIdentity {
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

function Test-ToolkitExecutorTargetScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$RollbackManifest,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    $taskName = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceName"
    $taskPath = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Source"
    $sourceType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType"
    $sourceFinding = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFinding"
    $targetIdentity = Get-ToolkitFindingPropertyValue -Finding $RollbackManifest -Name "TargetIdentity"
    $category = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Category"
    $recommendation = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Recommendation"
    $expectedFinding = "${sourceType}: $taskName"
    $nameAllowed = @(
        $ExecutionPolicy.TaskNamePatterns |
            Where-Object {
                $taskName.IndexOf(
                    [string]$_,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -ge 0
            }
    ).Count -gt 0

    if (-not (Test-ToolkitExecutorLiteralIdentity -TaskName $taskName -TaskPath $taskPath)) {
        return [PSCustomObject]@{
            Allowed      = $false
            DecisionCode = "UnsafeTargetIdentity"
            Reason       = "The scheduled-task name or path is not a safe literal identity."
            Remediation  = "Regenerate the plan from a scheduled task with a literal name and path."
        }
    }

    if (
        -not $taskPath.StartsWith(
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
        -not (Test-ToolkitExecutionStringEquals $category "Telemetry") -or
        -not (Test-ToolkitExecutionStringEquals $recommendation "Review / likely disable") -or
        -not (Test-ToolkitExecutionStringEquals $targetIdentity $taskName) -or
        -not (Test-ToolkitExecutionStringEquals $sourceFinding $expectedFinding)
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

        default {
            throw "Unsupported executor."
        }
    }
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
        -Parts @(
            Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType"
            Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceName"
            Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Source"
            Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceVersion"
            Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "ReportFile"
        )
    $expectedPlanId = Get-ToolkitStableId `
        -Prefix "OP" `
        -Parts @($expectedSourceFindingId, $actionId)

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
                            $observedState = [string]$currentObject.State
                            $currentStateValid = (
                                (Test-ToolkitExecutionStringEquals $observedState $PlanEntry.CurrentState) -and
                                (Test-ToolkitExecutionStringEquals $observedState $beforeState.CurrentState)
                            )
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
                        elseif (
                            Test-ToolkitExecutionStringEquals `
                                $observedState `
                                $executionPolicy.TargetState
                        ) {
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

function Invoke-ToolkitAllowedExecutionOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskName,
        [Parameter(Mandatory)][string]$TaskPath,
        [Parameter(Mandatory)][ValidateSet("DisableScheduledTask")]
        [string]$ExecutorId
    )

    switch ($ExecutorId) {
        "DisableScheduledTask" {
            Disable-ScheduledTask `
                -TaskName $TaskName `
                -TaskPath $TaskPath `
                -ErrorAction Stop |
                Out-Null
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

        $target = "$($planEntry.Source)$($planEntry.SourceName)"
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
        $taskName = [string]$manifestEntry.TargetIdentity
        $taskPath = [string]$planEntry.Source
        try {
            Invoke-ToolkitAllowedExecutionOperation `
                -TaskName $taskName `
                -TaskPath $taskPath `
                -ExecutorId $policy.ExecutorId

            try {
                $postObject = Get-ToolkitExecutorCurrentObject `
                    -PlanEntry $planEntry `
                    -RollbackManifest $manifestEntry `
                    -ExecutionPolicy $policy
                $observedState = [string]$postObject.State
            }
            catch {
                $observedState = ""
                throw "The operation returned, but post-state validation failed: $($_.Exception.Message)"
            }

            if (-not (Test-ToolkitExecutionStringEquals $observedState $policy.TargetState)) {
                $rollbackRequired = -not (
                    Test-ToolkitExecutionStringEquals `
                        $observedState `
                        $planEntry.CurrentState
                )
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
                $observedState = [string]$failureObject.State

                if (Test-ToolkitExecutionStringEquals $observedState $policy.TargetState) {
                    $applied = $true
                    $status = "FailedAfterStateChange"
                    $decisionCode = "ExecutionFailedAfterStateChange"
                }
                elseif (
                    Test-ToolkitExecutionStringEquals `
                        $observedState `
                        $planEntry.CurrentState
                ) {
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
                -MutationAttempted $true `
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

Export-ModuleMember -Function Invoke-ToolkitOptimizationExecutor

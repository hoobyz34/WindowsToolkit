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
        MutatingCommand            = "Disable-ScheduledTask"
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
            (Test-ToolkitOptimizationTextEquals $policy.mutatingCommand $contract.MutatingCommand) -and
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

    return $null
}

function Test-ToolkitOptimizationExecutorScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PlanEntry,
        [Parameter(Mandatory)][object]$ExecutionPolicy
    )

    $taskName = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceName"
    $taskPath = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "Source"
    $sourceType = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceType"
    $sourceFinding = Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFinding"
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

    if (-not (Test-ToolkitOptimizationLiteralTaskIdentity -TaskName $taskName -TaskPath $taskPath)) {
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
            Remediation        = "Retain the item or regenerate it from the dedicated HP Scheduled Task analyzer path."
            ExecutionPolicy    = $null
        }
    }

    if (
        Test-ToolkitOptimizationTextEquals `
            (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "CurrentState") `
            $executionPolicy.TargetState
    ) {
        return [PSCustomObject]@{
            Allowed            = $false
            DecisionCode       = "AlreadyAtTargetState"
            SafetyPolicyResult = "Blocked - Target State"
            Reason             = "The scheduled task is already in the executor target state."
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
        Reason             = "The action matches the fixed executor policy and dedicated HP scheduled-task scope."
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
    $sourceFindingId = Get-ToolkitStableId -Prefix "TF" -Parts @($type, $name, $source, $version, $reportFile)
    $planId = Get-ToolkitStableId -Prefix "OP" -Parts @($sourceFindingId, [string]$action.id)
    $confidence = Get-ToolkitFindingPropertyValue -Finding $Finding -Name "Confidence" -Default ([string]$action.confidence)

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

    return New-ToolkitRollbackManifestEntry `
        -ManifestId $manifestId `
        -PreflightId (Get-ToolkitFindingPropertyValue -Finding $PreflightResult -Name "PreflightId") `
        -PlanId $planId `
        -SourceFindingId $sourceFindingId `
        -ActionId $actionId `
        -SourceFinding (Get-ToolkitFindingPropertyValue -Finding $PlanEntry -Name "SourceFinding") `
        -SourceName $sourceName `
        -SourceType $sourceType `
        -TargetIdentity $sourceName `
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

function Resolve-ToolkitFindingSource {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($Source)) {
        return "Source unavailable"
    }

    return $Source
}

function New-ToolkitFinding {
    param(
        [string]$Name,
        [string]$Type,
        [string]$Vendor,
        [string]$Category,
        [string]$Recommendation,
        [string]$Risk,
        [string]$Reason,
        [string]$Source = "",
        [string]$Version = "",
        [string]$State = "",
        [string]$ServiceName = "",
        [string]$ServiceDisplayName = "",
        [string]$StartupType = "",
        [string]$Dependencies = "",
        [string]$RecoveryConfiguration = ""
    )

    [PSCustomObject]@{
        Name           = $Name
        Type           = $Type
        Vendor         = $Vendor
        Category       = $Category
        Recommendation = $Recommendation
        Risk           = $Risk
        Reason         = $Reason
        Source         = Resolve-ToolkitFindingSource -Source $Source
        Version        = $Version
        State          = $State
        ServiceName    = $ServiceName
        ServiceDisplayName = $ServiceDisplayName
        StartupType    = $StartupType
        Dependencies   = $Dependencies
        RecoveryConfiguration = $RecoveryConfiguration
    }
}

function New-ToolkitOptimizationPlanEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PlanId,
        [Parameter(Mandatory)][string]$SourceFindingId,
        [Parameter(Mandatory)][string]$SourceFinding,
        [Parameter(Mandatory)][string]$SourceName,
        [Parameter(Mandatory)][string]$SourceType,
        [string]$SourceVersion = "",
        [Parameter(Mandatory)][string]$ProposedAction,
        [Parameter(Mandatory)][string]$ActionId,
        [string]$CurrentState = "",
        [string]$Risk = "Unknown",
        [string]$Reason = "",
        [string]$Confidence = "Unknown",
        [string]$Category = "Unknown",
        [string]$Vendor = "Unknown",
        [string]$Recommendation = "Review",
        [string]$Source = "",
        [string]$ReportFile = "",
        [string]$ServiceName = "",
        [string]$ServiceDisplayName = "",
        [string]$StartupType = "",
        [string]$Dependencies = "",
        [string]$RecoveryConfiguration = "",
        [Parameter(Mandatory)][bool]$RequiresConfirmation,
        [Parameter(Mandatory)][string]$ConfirmationRequirement,
        [string]$PlanStatus = "Pending Review"
    )

    [PSCustomObject]@{
        PlanId                  = $PlanId
        SourceFindingId         = $SourceFindingId
        SourceFinding           = $SourceFinding
        SourceName              = $SourceName
        SourceType              = $SourceType
        SourceVersion           = $SourceVersion
        ProposedAction          = $ProposedAction
        ActionId                = $ActionId
        CurrentState            = $CurrentState
        Risk                    = $Risk
        Reason                  = $Reason
        Confidence              = $Confidence
        Category                = $Category
        Vendor                  = $Vendor
        Recommendation          = $Recommendation
        Source                  = $Source
        ReportFile              = $ReportFile
        ServiceName             = $ServiceName
        ServiceDisplayName      = $ServiceDisplayName
        StartupType             = $StartupType
        Dependencies            = $Dependencies
        RecoveryConfiguration   = $RecoveryConfiguration
        RequiresConfirmation    = $RequiresConfirmation
        ConfirmationRequirement = $ConfirmationRequirement
        PlanStatus              = $PlanStatus
    }
}

function New-ToolkitOptimizationPreflightResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PreflightId,
        [Parameter(Mandatory)][string]$PlanId,
        [Parameter(Mandatory)][string]$SourceFindingId,
        [Parameter(Mandatory)][string]$ActionId,
        [Parameter(Mandatory)][string]$SourceFinding,
        [Parameter(Mandatory)][string]$SourceName,
        [Parameter(Mandatory)][string]$SourceType,
        [Parameter(Mandatory)][string]$ProposedAction,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$EligibilityStatus,
        [Parameter(Mandatory)][bool]$IsEligible,
        [Parameter(Mandatory)][bool]$IsBlocked,
        [Parameter(Mandatory)][bool]$ConfirmationRequired,
        [Parameter(Mandatory)][string]$ConfirmationStatus,
        [Parameter(Mandatory)][string]$CurrentStateValidationResult,
        [Parameter(Mandatory)][string]$SafetyPolicyResult,
        [Parameter(Mandatory)][bool]$AdministratorRequired,
        [Parameter(Mandatory)][bool]$AdministratorReady,
        [Parameter(Mandatory)][bool]$RestorePointRequired,
        [Parameter(Mandatory)][string]$RestorePointCapability,
        [Parameter(Mandatory)][bool]$RestorePointReady,
        [Parameter(Mandatory)][string]$ReversibilityStatus,
        [Parameter(Mandatory)][string]$Reasons,
        [Parameter(Mandatory)][string]$Remediation
    )

    [PSCustomObject]@{
        PreflightId                  = $PreflightId
        PlanId                       = $PlanId
        SourceFindingId              = $SourceFindingId
        ActionId                     = $ActionId
        SourceFinding                = $SourceFinding
        SourceName                   = $SourceName
        SourceType                   = $SourceType
        ProposedAction               = $ProposedAction
        Status                       = $Status
        EligibilityStatus            = $EligibilityStatus
        IsEligible                   = $IsEligible
        IsBlocked                    = $IsBlocked
        ConfirmationRequired         = $ConfirmationRequired
        ConfirmationStatus           = $ConfirmationStatus
        CurrentStateValidationResult = $CurrentStateValidationResult
        SafetyPolicyResult           = $SafetyPolicyResult
        AdministratorRequired        = $AdministratorRequired
        AdministratorReady           = $AdministratorReady
        RestorePointRequired         = $RestorePointRequired
        RestorePointCapability       = $RestorePointCapability
        RestorePointReady            = $RestorePointReady
        ReversibilityStatus          = $ReversibilityStatus
        Reasons                      = $Reasons
        Remediation                  = $Remediation
    }
}

function New-ToolkitRollbackManifestEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestId,
        [Parameter(Mandatory)][string]$PreflightId,
        [Parameter(Mandatory)][string]$PlanId,
        [Parameter(Mandatory)][string]$SourceFindingId,
        [Parameter(Mandatory)][string]$ActionId,
        [Parameter(Mandatory)][string]$SourceFinding,
        [Parameter(Mandatory)][string]$SourceName,
        [Parameter(Mandatory)][string]$SourceType,
        [Parameter(Mandatory)][string]$TargetIdentity,
        [Parameter(Mandatory)][string]$OperationType,
        [Parameter(Mandatory)][string]$IntendedOperation,
        [Parameter(Mandatory)][string]$BeforeStateSnapshot,
        [Parameter(Mandatory)][string]$BeforeStateHash,
        [Parameter(Mandatory)][bool]$BeforeStateCaptured,
        [Parameter(Mandatory)][string]$RequiredBeforeStateFields,
        [string]$MissingBeforeStateFields = "",
        [Parameter(Mandatory)][bool]$IsReversible,
        [Parameter(Mandatory)][string]$ReversibilityStatement,
        [Parameter(Mandatory)][bool]$RestorePointRequired,
        [Parameter(Mandatory)][string]$SafetyPolicyResult
    )

    [PSCustomObject]@{
        ManifestId                = $ManifestId
        PreflightId               = $PreflightId
        PlanId                    = $PlanId
        SourceFindingId           = $SourceFindingId
        ActionId                  = $ActionId
        SourceFinding             = $SourceFinding
        SourceName                = $SourceName
        SourceType                = $SourceType
        TargetIdentity            = $TargetIdentity
        OperationType             = $OperationType
        IntendedOperation         = $IntendedOperation
        BeforeStateSnapshot       = $BeforeStateSnapshot
        BeforeStateHash           = $BeforeStateHash
        BeforeStateCaptured       = $BeforeStateCaptured
        RequiredBeforeStateFields = $RequiredBeforeStateFields
        MissingBeforeStateFields  = $MissingBeforeStateFields
        IsReversible              = $IsReversible
        ReversibilityStatement    = $ReversibilityStatement
        RestorePointRequired      = $RestorePointRequired
        SafetyPolicyResult        = $SafetyPolicyResult
    }
}

function New-ToolkitOptimizationExecutionResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ExecutionId,
        [Parameter(Mandatory)][string]$PlanId,
        [string]$PreflightId = "",
        [string]$ManifestId = "",
        [Parameter(Mandatory)][string]$ActionId,
        [Parameter(Mandatory)][string]$SourceFinding,
        [Parameter(Mandatory)][string]$SourceName,
        [Parameter(Mandatory)][string]$SourceType,
        [Parameter(Mandatory)][string]$OperationType,
        [string]$ExecutorId = "",
        [Parameter(Mandatory)][string]$AttemptMode,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$DecisionCode,
        [Parameter(Mandatory)][bool]$Applied,
        [Parameter(Mandatory)][bool]$MutationAttempted,
        [Parameter(Mandatory)][bool]$ShouldProcessApproved,
        [Parameter(Mandatory)][bool]$PolicyAllowed,
        [Parameter(Mandatory)][bool]$PreflightValid,
        [Parameter(Mandatory)][bool]$ManifestValid,
        [Parameter(Mandatory)][bool]$CurrentStateValid,
        [Parameter(Mandatory)][bool]$ConfirmationProvided,
        [string]$ObservedStateAfter = "",
        [Parameter(Mandatory)][bool]$RollbackRequired,
        [Parameter(Mandatory)][string]$RollbackStatus,
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$Remediation,
        [string]$BeforeStateHash = "",
        [string]$RollbackOperationType = "",
        [string]$RollbackTargetState = "",
        [Parameter(Mandatory)][datetime]$AttemptedAtUtc
    )

    [PSCustomObject]@{
        ExecutionId             = $ExecutionId
        PlanId                  = $PlanId
        PreflightId             = $PreflightId
        ManifestId              = $ManifestId
        ActionId                = $ActionId
        SourceFinding           = $SourceFinding
        SourceName              = $SourceName
        SourceType              = $SourceType
        OperationType           = $OperationType
        ExecutorId              = $ExecutorId
        AttemptMode             = $AttemptMode
        Status                  = $Status
        DecisionCode            = $DecisionCode
        Applied                 = $Applied
        MutationAttempted       = $MutationAttempted
        ShouldProcessApproved   = $ShouldProcessApproved
        PolicyAllowed           = $PolicyAllowed
        PreflightValid          = $PreflightValid
        ManifestValid           = $ManifestValid
        CurrentStateValid       = $CurrentStateValid
        ConfirmationProvided    = $ConfirmationProvided
        ObservedStateAfter      = $ObservedStateAfter
        RollbackRequired        = $RollbackRequired
        RollbackStatus          = $RollbackStatus
        Reason                  = $Reason
        Remediation             = $Remediation
        BeforeStateHash         = $BeforeStateHash
        RollbackOperationType   = $RollbackOperationType
        RollbackTargetState     = $RollbackTargetState
        AttemptedAtUtc          = $AttemptedAtUtc
    }
}

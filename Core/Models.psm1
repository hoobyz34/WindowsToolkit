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
        [string]$State = ""
    )

    [PSCustomObject]@{
        Name           = $Name
        Type           = $Type
        Vendor         = $Vendor
        Category       = $Category
        Recommendation = $Recommendation
        Risk           = $Risk
        Reason         = $Reason
        Source         = $Source
        Version        = $Version
        State          = $State
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

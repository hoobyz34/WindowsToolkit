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

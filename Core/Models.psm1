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
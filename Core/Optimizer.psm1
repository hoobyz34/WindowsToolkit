Import-Module (Join-Path $PSScriptRoot "Models.psm1") -Force

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

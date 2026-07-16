function Get-ToolkitReportPath {
    [CmdletBinding()]
    param()

    if (-not $Global:ToolkitRunPath) {
        $root = Split-Path -Parent $PSScriptRoot
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

        $Global:ToolkitRunPath = Join-Path `
            $root `
            "Reports\Run_$timestamp"
    }

    if (-not (Test-Path $Global:ToolkitRunPath)) {
        New-Item `
            -ItemType Directory `
            -Path $Global:ToolkitRunPath `
            -Force |
            Out-Null
    }

    return $Global:ToolkitRunPath
}

function Save-TextReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Command
    )

    $reportPath = Get-ToolkitReportPath
    $path = Join-Path $reportPath "$Name.txt"

    Write-Log "Creating report: $Name"

    try {
        & $Command |
            Out-File `
                -FilePath $path `
                -Encoding utf8 `
                -Width 300
    }
    catch {
        "ERROR creating report: $Name" |
            Out-File `
                -FilePath $path `
                -Encoding utf8

        $_ |
            Out-File `
                -FilePath $path `
                -Append `
                -Encoding utf8
    }

    return $path
}

function Save-CsvReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Data
    )

    $reportPath = Get-ToolkitReportPath
    $path = Join-Path $reportPath "$Name.csv"

    $Data |
        Export-Csv `
            -Path $path `
            -NoTypeInformation `
            -Encoding utf8

    return $path
}

function Save-JsonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Data,

        [ValidateRange(2, 100)]
        [int]$Depth = 10
    )

    $reportPath = Get-ToolkitReportPath
    $path = Join-Path $reportPath "$Name.json"

    $Data |
        ConvertTo-Json `
            -Depth $Depth |
        Set-Content `
            -Path $path `
            -Encoding utf8

    return $path
}

function Save-ToolkitStructuredReports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Data,

        [Parameter(Mandatory)]
        [string[]]$Columns
    )

    if ($Data.Count -gt 0) {
        return [PSCustomObject]@{
            CsvPath = Save-CsvReport -Name $Name -Data $Data
            JsonPath = Save-JsonReport -Name $Name -Data $Data -Depth 10
        }
    }

    $reportPath = Get-ToolkitReportPath
    $csvPath = Join-Path $reportPath "$Name.csv"
    $jsonPath = Join-Path $reportPath "$Name.json"

    Set-Content -Path $csvPath -Value ($Columns -join ",") -Encoding utf8
    Set-Content -Path $jsonPath -Value "[]" -Encoding utf8

    return [PSCustomObject]@{
        CsvPath = $csvPath
        JsonPath = $jsonPath
    }
}

function Save-ToolkitOptimizationPlanReports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Plan
    )

    $columns = @(
        "PlanId", "SourceFindingId", "SourceFinding", "ProposedAction",
        "SourceName", "SourceType", "SourceVersion", "ActionId",
        "CurrentState", "Risk", "Reason", "Confidence", "Category", "Vendor",
        "Recommendation", "Source", "ReportFile", "RequiresConfirmation",
        "ConfirmationRequirement", "PlanStatus"
    )

    return Save-ToolkitStructuredReports `
        -Name "Optimization_Plan" `
        -Data $Plan `
        -Columns $columns
}

function Save-ToolkitOptimizationPreflightReports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PreflightResults
    )

    $columns = @(
        "PreflightId", "PlanId", "SourceFindingId", "ActionId",
        "SourceFinding", "SourceName", "SourceType", "ProposedAction",
        "Status", "EligibilityStatus", "IsEligible", "IsBlocked",
        "ConfirmationRequired", "ConfirmationStatus",
        "CurrentStateValidationResult", "SafetyPolicyResult",
        "AdministratorRequired", "AdministratorReady", "RestorePointRequired",
        "RestorePointCapability", "RestorePointReady", "ReversibilityStatus",
        "Reasons", "Remediation"
    )

    return Save-ToolkitStructuredReports `
        -Name "Optimization_Preflight" `
        -Data $PreflightResults `
        -Columns $columns
}

function Save-ToolkitRollbackManifestReports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RollbackManifest
    )

    $columns = @(
        "ManifestId", "PreflightId", "PlanId", "SourceFindingId", "ActionId",
        "SourceFinding", "SourceName", "SourceType", "TargetIdentity",
        "OperationType", "IntendedOperation", "BeforeStateSnapshot",
        "BeforeStateHash", "BeforeStateCaptured", "RequiredBeforeStateFields",
        "MissingBeforeStateFields", "IsReversible", "ReversibilityStatement",
        "RestorePointRequired", "SafetyPolicyResult"
    )

    return Save-ToolkitStructuredReports `
        -Name "Rollback_Manifest" `
        -Data $RollbackManifest `
        -Columns $columns
}

function Save-HtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Html
    )

    $reportPath = Get-ToolkitReportPath
    $path = Join-Path $reportPath "$Name.html"

    Set-Content `
        -Path $path `
        -Value $Html `
        -Encoding utf8

    return $path
}

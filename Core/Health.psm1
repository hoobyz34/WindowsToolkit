function Test-ToolkitUnknownValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ([string]::IsNullOrWhiteSpace([string]$Value)) {
        return $true
    }

    return [string]$Value -match '^(Unknown|Unclassified|N/A|None)$'
}

function Test-ToolkitReviewRecommendation {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Recommendation
    )

    if ([string]::IsNullOrWhiteSpace([string]$Recommendation)) {
        return $false
    }

    return [string]$Recommendation -match (
        'review|disable|remove|uninstall|investigate'
    )
}

function Test-ToolkitHighRisk {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Risk
    )

    if ([string]::IsNullOrWhiteSpace([string]$Risk)) {
        return $false
    }

    return [string]$Risk -match '^(Critical|High)$'
}

function Get-ToolkitScoreStatus {
    [CmdletBinding()]
    param(
        [ValidateRange(0, 100)]
        [int]$Score
    )

    if ($Score -ge 90) {
        return "Excellent"
    }

    if ($Score -ge 75) {
        return "Good"
    }

    if ($Score -ge 60) {
        return "Needs Review"
    }

    if ($Score -gt 0) {
        return "Limited"
    }

    return "No Data"
}

function Get-ToolkitInventoryHealthScore {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Findings
    )

    $items = @($Findings)
    $totalItems = $items.Count

    if ($totalItems -eq 0) {
        return [PSCustomObject]@{
            MetricName                 = "Inventory Assessment Score"
            Score                      = 0
            Status                     = "No Data"
            TotalItems                 = 0
            CompleteItems              = 0
            UnknownVendorItems         = 0
            UnknownCategoryItems       = 0
            UnknownRecommendationItems = 0
            UnknownRiskItems           = 0
            ReviewItems                = 0
            HighRiskReviewItems        = 0
            CoveragePercent            = 0
            Components                 = @()
            Factors                    = @(
                "No inventory findings were available."
            )
            Explanation                = (
                "The score measures inventory clarity and assessment " +
                "readiness, not raw computer performance."
            )
        }
    }

    $unknownVendor = @(
        $items |
            Where-Object {
                Test-ToolkitUnknownValue $_.Vendor
            }
    ).Count

    $unknownCategory = @(
        $items |
            Where-Object {
                Test-ToolkitUnknownValue $_.Category
            }
    ).Count

    $unknownRecommendation = @(
        $items |
            Where-Object {
                Test-ToolkitUnknownValue $_.Recommendation
            }
    ).Count

    $unknownRisk = @(
        $items |
            Where-Object {
                Test-ToolkitUnknownValue $_.Risk
            }
    ).Count

    $reviewItems = @(
        $items |
            Where-Object {
                Test-ToolkitReviewRecommendation `
                    -Recommendation $_.Recommendation
            }
    )

    $highRiskReviewItems = @(
        $reviewItems |
            Where-Object {
                Test-ToolkitHighRisk `
                    -Risk $_.Risk
            }
    )

    $completeItems = @(
        $items |
            Where-Object {
                -not (
                    Test-ToolkitUnknownValue $_.Vendor
                ) -and
                -not (
                    Test-ToolkitUnknownValue $_.Category
                ) -and
                -not (
                    Test-ToolkitUnknownValue $_.Recommendation
                ) -and
                -not (
                    Test-ToolkitUnknownValue $_.Risk
                ) -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$_.Reason
                )
            }
    ).Count

    $fieldCount = $totalItems * 4

    $knownFieldCount = $fieldCount - (
        $unknownVendor +
        $unknownCategory +
        $unknownRecommendation +
        $unknownRisk
    )

    $coverageRatio = if ($fieldCount -gt 0) {
        $knownFieldCount / $fieldCount
    }
    else {
        0
    }

    $completeRatio = $completeItems / $totalItems
    $knownRecommendationRatio = (
        $totalItems - $unknownRecommendation
    ) / $totalItems

    $reviewRatio = $reviewItems.Count / $totalItems
    $highRiskReviewRatio = $highRiskReviewItems.Count / $totalItems

    $coveragePoints = [math]::Round(
        40 * $coverageRatio,
        1
    )

    $completenessPoints = [math]::Round(
        25 * $completeRatio,
        1
    )

    $recommendationPoints = [math]::Round(
        20 * $knownRecommendationRatio,
        1
    )

    $reviewReadinessPoints = [math]::Round(
        10 * (1 - [math]::Min($reviewRatio, 1)),
        1
    )

    $safetyPoints = [math]::Round(
        5 * (1 - [math]::Min($highRiskReviewRatio, 1)),
        1
    )

    $score = [math]::Round(
        $coveragePoints +
        $completenessPoints +
        $recommendationPoints +
        $reviewReadinessPoints +
        $safetyPoints
    )

    $score = [math]::Max(
        0,
        [math]::Min(100, $score)
    )

    $factors = [System.Collections.Generic.List[string]]::new()

    if ($unknownRecommendation -gt 0) {
        $factors.Add(
            "$unknownRecommendation item(s) have unknown recommendations."
        )
    }

    if ($unknownVendor -gt 0) {
        $factors.Add(
            "$unknownVendor item(s) have unknown vendors."
        )
    }

    if ($unknownCategory -gt 0) {
        $factors.Add(
            "$unknownCategory item(s) have unknown categories."
        )
    }

    if ($reviewItems.Count -gt 0) {
        $factors.Add(
            "$($reviewItems.Count) item(s) require review."
        )
    }

    if ($highRiskReviewItems.Count -gt 0) {
        $factors.Add(
            "$($highRiskReviewItems.Count) high-risk item(s) require review."
        )
    }

    if ($factors.Count -eq 0) {
        $factors.Add(
            "All inventoried items contain complete, actionable classifications."
        )
    }

    return [PSCustomObject]@{
        MetricName                 = "Inventory Assessment Score"
        Score                      = [int]$score
        Status                     = Get-ToolkitScoreStatus `
            -Score ([int]$score)
        TotalItems                 = $totalItems
        CompleteItems              = $completeItems
        UnknownVendorItems         = $unknownVendor
        UnknownCategoryItems       = $unknownCategory
        UnknownRecommendationItems = $unknownRecommendation
        UnknownRiskItems           = $unknownRisk
        ReviewItems                = $reviewItems.Count
        HighRiskReviewItems        = $highRiskReviewItems.Count
        CoveragePercent            = [math]::Round(
            100 * $coverageRatio,
            1
        )
        Components                 = @(
            [PSCustomObject]@{
                Name      = "Classification Coverage"
                Points    = $coveragePoints
                Maximum   = 40
                Percentage = [math]::Round(
                    100 * $coverageRatio,
                    1
                )
            }
            [PSCustomObject]@{
                Name      = "Complete Findings"
                Points    = $completenessPoints
                Maximum   = 25
                Percentage = [math]::Round(
                    100 * $completeRatio,
                    1
                )
            }
            [PSCustomObject]@{
                Name      = "Recommendation Coverage"
                Points    = $recommendationPoints
                Maximum   = 20
                Percentage = [math]::Round(
                    100 * $knownRecommendationRatio,
                    1
                )
            }
            [PSCustomObject]@{
                Name      = "Review Readiness"
                Points    = $reviewReadinessPoints
                Maximum   = 10
                Percentage = [math]::Round(
                    100 * (1 - [math]::Min($reviewRatio, 1)),
                    1
                )
            }
            [PSCustomObject]@{
                Name      = "Safety Confidence"
                Points    = $safetyPoints
                Maximum   = 5
                Percentage = [math]::Round(
                    100 * (
                        1 -
                        [math]::Min($highRiskReviewRatio, 1)
                    ),
                    1
                )
            }
        )
        Factors                    = @($factors)
        Explanation                = (
            "The score measures inventory clarity, classification coverage, " +
            "and assessment readiness. It does not measure raw performance " +
            "and does not authorize automatic system changes."
        )
    }
}

function ConvertTo-ToolkitHealthScoreRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$HealthScore
    )

    $rows = @(
        [PSCustomObject]@{
            Section = "Overview"
            Name    = "Score"
            Value   = $HealthScore.Score
        }
        [PSCustomObject]@{
            Section = "Overview"
            Name    = "Status"
            Value   = $HealthScore.Status
        }
        [PSCustomObject]@{
            Section = "Overview"
            Name    = "Total Items"
            Value   = $HealthScore.TotalItems
        }
        [PSCustomObject]@{
            Section = "Overview"
            Name    = "Complete Items"
            Value   = $HealthScore.CompleteItems
        }
        [PSCustomObject]@{
            Section = "Overview"
            Name    = "Coverage Percent"
            Value   = $HealthScore.CoveragePercent
        }
        [PSCustomObject]@{
            Section = "Overview"
            Name    = "Review Items"
            Value   = $HealthScore.ReviewItems
        }
        [PSCustomObject]@{
            Section = "Overview"
            Name    = "High-Risk Review Items"
            Value   = $HealthScore.HighRiskReviewItems
        }
    )

    foreach ($component in @($HealthScore.Components)) {
        $rows += [PSCustomObject]@{
            Section = "Component"
            Name    = $component.Name
            Value   = "$($component.Points)/$($component.Maximum)"
        }
    }

    foreach ($factor in @($HealthScore.Factors)) {
        $rows += [PSCustomObject]@{
            Section = "Factor"
            Name    = $factor
            Value   = ""
        }
    }

    return $rows
}

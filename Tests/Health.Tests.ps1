Describe "Inventory Health Score" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Health.psm1" -Force
    }

    It "returns No Data when no findings exist" {
        $result = Get-ToolkitInventoryHealthScore `
            -Findings @()

        $result.Score |
            Should -Be 0

        $result.Status |
            Should -Be "No Data"

        $result.TotalItems |
            Should -Be 0
    }

    It "awards a perfect score to complete keep findings" {
        $findings = @(
            [PSCustomObject]@{
                Vendor         = "Microsoft"
                Category       = "Required"
                Recommendation = "Keep"
                Risk           = "Low"
                Reason         = "Required component."
            }
            [PSCustomObject]@{
                Vendor         = "Intel"
                Category       = "Hardware Driver"
                Recommendation = "Keep"
                Risk           = "Medium"
                Reason         = "Hardware support."
            }
        )

        $result = Get-ToolkitInventoryHealthScore `
            -Findings $findings

        $result.Score |
            Should -Be 100

        $result.Status |
            Should -Be "Excellent"
    }

    It "reduces the score for unknown classifications" {
        $findings = @(
            [PSCustomObject]@{
                Vendor         = "Unknown"
                Category       = "Unknown"
                Recommendation = "Unknown"
                Risk           = "Unknown"
                Reason         = ""
            }
        )

        $result = Get-ToolkitInventoryHealthScore `
            -Findings $findings

        $result.Score |
            Should -BeLessThan 60

        $result.UnknownVendorItems |
            Should -Be 1

        $result.UnknownRecommendationItems |
            Should -Be 1
    }

    It "counts review recommendations" {
        $findings = @(
            [PSCustomObject]@{
                Vendor         = "HP"
                Category       = "Telemetry"
                Recommendation = "Review / likely disable"
                Risk           = "Low"
                Reason         = "Telemetry component."
            }
        )

        $result = Get-ToolkitInventoryHealthScore `
            -Findings $findings

        $result.ReviewItems |
            Should -Be 1
    }

    It "counts high-risk review recommendations" {
        $findings = @(
            [PSCustomObject]@{
                Vendor         = "Microsoft"
                Category       = "Required"
                Recommendation = "Review"
                Risk           = "High"
                Reason         = "Manual review required."
            }
        )

        $result = Get-ToolkitInventoryHealthScore `
            -Findings $findings

        $result.HighRiskReviewItems |
            Should -Be 1
    }

    It "treats blank values as unknown" {
        Test-ToolkitUnknownValue `
            -Value "" |
            Should -BeTrue

        Test-ToolkitUnknownValue `
            -Value $null |
            Should -BeTrue
    }

    It "does not treat known values as unknown" {
        Test-ToolkitUnknownValue `
            -Value "Microsoft" |
            Should -BeFalse
    }

    It "classifies score status consistently" {
        Get-ToolkitScoreStatus -Score 95 |
            Should -Be "Excellent"

        Get-ToolkitScoreStatus -Score 80 |
            Should -Be "Good"

        Get-ToolkitScoreStatus -Score 65 |
            Should -Be "Needs Review"

        Get-ToolkitScoreStatus -Score 40 |
            Should -Be "Limited"

        Get-ToolkitScoreStatus -Score 0 |
            Should -Be "No Data"
    }

    It "returns explainable score components" {
        $findings = @(
            [PSCustomObject]@{
                Vendor         = "Microsoft"
                Category       = "Required"
                Recommendation = "Keep"
                Risk           = "Low"
                Reason         = "Required component."
            }
        )

        $result = Get-ToolkitInventoryHealthScore `
            -Findings $findings

        $result.Components.Count |
            Should -Be 5

        $result.Components.Name |
            Should -Contain "Classification Coverage"

        $result.Components.Name |
            Should -Contain "Safety Confidence"
    }

    It "converts the result into flat report rows" {
        $result = Get-ToolkitInventoryHealthScore `
            -Findings @()

        $rows = ConvertTo-ToolkitHealthScoreRows `
            -HealthScore $result

        $rows.Section |
            Should -Contain "Overview"

        $rows.Name |
            Should -Contain "Score"

        $rows.Name |
            Should -Contain "Status"
    }

    It "never returns a score below zero or above 100" {
        $findings = 1..100 |
            ForEach-Object {
                [PSCustomObject]@{
                    Vendor         = "Unknown"
                    Category       = "Unknown"
                    Recommendation = "Review"
                    Risk           = "High"
                    Reason         = ""
                }
            }

        $result = Get-ToolkitInventoryHealthScore `
            -Findings $findings

        $result.Score |
            Should -BeGreaterOrEqual 0

        $result.Score |
            Should -BeLessOrEqual 100
    }
}

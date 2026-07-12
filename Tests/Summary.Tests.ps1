Describe "Inventory Summary" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Reporting.psm1" -Force
        Import-Module "$Root\Core\Summary.psm1" -Force
    }

    BeforeEach {
        $ReportPath = Join-Path `
            $TestDrive `
            "Reports"

        New-Item `
            -ItemType Directory `
            -Path $ReportPath `
            -Force |
            Out-Null

        @(
            [PSCustomObject]@{
                Name           = "Service A"
                Type           = "Service"
                Vendor         = "Microsoft"
                Category       = "Required"
                Recommendation = "Keep"
                Risk           = "High"
                Reason         = "Test"
                Source         = "Test"
                Version        = ""
                State          = "Running"
            }

            [PSCustomObject]@{
                Name           = "Service B"
                Type           = "Service"
                Vendor         = "HP"
                Category       = "Telemetry"
                Recommendation = "Review"
                Risk           = "Low"
                Reason         = "Test"
                Source         = "Test"
                Version        = ""
                State          = "Stopped"
            }
        ) |
            Export-Csv `
                -Path (Join-Path $ReportPath "Services_Report.csv") `
                -NoTypeInformation

        @(
            [PSCustomObject]@{
                Name           = "Driver A"
                Type           = "Driver"
                Vendor         = "Intel"
                Category       = "Hardware Driver"
                Recommendation = "Keep"
                Risk           = "Medium"
                Reason         = "Test"
                Source         = "Test"
                Version        = "1.0"
                State          = "System"
            }
        ) |
            Export-Csv `
                -Path (Join-Path $ReportPath "Driver_Analyzer.csv") `
                -NoTypeInformation
    }

    It "loads findings from every analyzer CSV" {
        $findings = Get-ToolkitReportFindings `
            -ReportPath $ReportPath

        $findings.Count |
            Should -Be 3
    }

    It "adds the source report filename to findings" {
        $findings = Get-ToolkitReportFindings `
            -ReportPath $ReportPath

        $findings.ReportFile |
            Should -Contain "Services_Report.csv"
    }

    It "counts reports and inventory items" {
        $summary = Get-ToolkitInventorySummary `
            -ReportPath $ReportPath

        $summary.ReportCount |
            Should -Be 2

        $summary.TotalItems |
            Should -Be 3
    }

    It "groups findings by type" {
        $summary = Get-ToolkitInventorySummary `
            -ReportPath $ReportPath

        $service = $summary.Types |
            Where-Object Name -eq "Service"

        $service.Count |
            Should -Be 2
    }

    It "groups findings by vendor" {
        $summary = Get-ToolkitInventorySummary `
            -ReportPath $ReportPath

        $summary.Vendors.Name |
            Should -Contain "Microsoft"

        $summary.Vendors.Name |
            Should -Contain "HP"

        $summary.Vendors.Name |
            Should -Contain "Intel"
    }

    It "groups findings by recommendation" {
        $summary = Get-ToolkitInventorySummary `
            -ReportPath $ReportPath

        $keep = $summary.Recommendations |
            Where-Object Name -eq "Keep"

        $keep.Count |
            Should -Be 2
    }

    It "converts the summary to flat CSV rows" {
        $summary = Get-ToolkitInventorySummary `
            -ReportPath $ReportPath

        $rows = ConvertTo-ToolkitSummaryRows `
            -Summary $summary

        $rows.Section |
            Should -Contain "Overview"

        $rows.Section |
            Should -Contain "Vendors"

        $rows.Section |
            Should -Contain "Recommendations"
    }

    It "returns an empty summary when no analyzer reports exist" {
        $EmptyPath = Join-Path `
            $TestDrive `
            "EmptyReports"

        New-Item `
            -ItemType Directory `
            -Path $EmptyPath |
            Out-Null

        $summary = Get-ToolkitInventorySummary `
            -ReportPath $EmptyPath

        $summary.ReportCount |
            Should -Be 0

        $summary.TotalItems |
            Should -Be 0
    }
}

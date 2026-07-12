Describe "HTML Inventory Dashboard" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Reporting.psm1" -Force
        Import-Module "$Root\Core\Dashboard.psm1" -Force

        $Summary = [PSCustomObject]@{
            GeneratedAt = [datetime]"2026-01-01T12:00:00"
            ReportPath = "C:\Test\Reports"
            ReportCount = 2
            TotalItems = 3
            Reports = @(
                [PSCustomObject]@{
                    Name = "Services.csv"
                    ItemCount = 2
                }
                [PSCustomObject]@{
                    Name = "Drivers.csv"
                    ItemCount = 1
                }
            )
            Types = @(
                [PSCustomObject]@{
                    Name = "Service"
                    Count = 2
                }
                [PSCustomObject]@{
                    Name = "Driver"
                    Count = 1
                }
            )
            Vendors = @(
                [PSCustomObject]@{
                    Name = "Microsoft"
                    Count = 2
                }
                [PSCustomObject]@{
                    Name = "Intel"
                    Count = 1
                }
            )
            Categories = @(
                [PSCustomObject]@{
                    Name = "Required"
                    Count = 2
                }
            )
            Recommendations = @(
                [PSCustomObject]@{
                    Name = "Keep"
                    Count = 3
                }
            )
            Risks = @(
                [PSCustomObject]@{
                    Name = "Low"
                    Count = 3
                }
            )
        }
    }

    BeforeEach {
        $Global:ToolkitRunPath = Join-Path `
            $TestDrive `
            "DashboardReports"
    }

    It "encodes unsafe HTML characters" {
        ConvertTo-ToolkitHtmlEncoded `
            -Value "<script>alert('x')</script>" |
            Should -Not -Match "<script>"
    }

    It "renders an HTML table" {
        $table = ConvertTo-ToolkitHtmlTable `
            -Data $Summary.Types `
            -Properties @(
                "Name"
                "Count"
            )

        $table |
            Should -Match "<table>"

        $table |
            Should -Match "Service"

        $table |
            Should -Match ">2<"
    }

    It "renders an empty-state message" {
        $table = ConvertTo-ToolkitHtmlTable `
            -Data @() `
            -Properties @(
                "Name"
                "Count"
            ) `
            -EmptyMessage "Nothing found."

        $table |
            Should -Match "Nothing found"
    }

    It "creates a complete HTML document" {
        $html = New-ToolkitHtmlDashboard `
            -Summary $Summary `
            -ToolkitVersion "0.3.0" `
            -ComputerName "TEST-PC"

        $html |
            Should -Match "<!DOCTYPE html>"

        $html |
            Should -Match "Inventory Dashboard"

        $html |
            Should -Match "TEST-PC"

        $html |
            Should -Match "WindowsToolkit v0.3.0"
    }

    It "includes summary counts in the dashboard" {
        $html = New-ToolkitHtmlDashboard `
            -Summary $Summary `
            -ToolkitVersion "0.3.0"

        $html |
            Should -Match "Inventory Items"

        $html |
            Should -Match ">3<"
    }

    It "includes all dashboard sections" {
        $html = New-ToolkitHtmlDashboard `
            -Summary $Summary

        @(
            "Analyzer Reports"
            "Inventory Types"
            "Top Vendors"
            "Categories"
            "Recommendations"
            "Risk Levels"
        ) | ForEach-Object {
            $html |
                Should -Match $_
        }
    }

    It "saves the dashboard as an HTML file" {
        $html = New-ToolkitHtmlDashboard `
            -Summary $Summary

        $path = Save-HtmlReport `
            -Name "DashboardTest" `
            -Html $html

        Test-Path $path |
            Should -BeTrue

        [System.IO.Path]::GetExtension($path) |
            Should -Be ".html"
    }

    It "writes valid dashboard content to disk" {
        $html = New-ToolkitHtmlDashboard `
            -Summary $Summary

        $path = Save-HtmlReport `
            -Name "DashboardTest" `
            -Html $html

        $savedHtml = Get-Content $path -Raw

        $savedHtml |
            Should -Match "<!DOCTYPE html>"

        $savedHtml |
            Should -Match "Inventory Dashboard"
    }
}

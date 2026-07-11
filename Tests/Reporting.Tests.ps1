Describe "Reporting" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Models.psm1" -Force
        Import-Module "$Root\Core\Reporting.psm1" -Force
    }

    BeforeEach {
        $Global:ToolkitRunPath = Join-Path `
            $TestDrive `
            "WindowsToolkit_Test"

        $Finding = New-ToolkitFinding `
            -Name "CPU" `
            -Type "Hardware" `
            -Vendor "Intel" `
            -Category "Recommended" `
            -Recommendation "Keep" `
            -Risk "Low" `
            -Reason "Unit Test" `
            -Source "Pester" `
            -Version "1.0" `
            -State "Installed"
    }

    It "Save-CsvReport creates a CSV" {
        Save-CsvReport `
            -Name "UnitTest" `
            -Data @($Finding)

        Test-Path "$Global:ToolkitRunPath\UnitTest.csv" |
            Should -BeTrue
    }

    It "CSV contains data" {
        Save-CsvReport `
            -Name "UnitTest" `
            -Data @($Finding)

        $csv = Import-Csv "$Global:ToolkitRunPath\UnitTest.csv"

        $csv.Count |
            Should -Be 1
    }

    It "CSV contains expected columns" {
        Save-CsvReport `
            -Name "UnitTest" `
            -Data @($Finding)

        $csv = Import-Csv "$Global:ToolkitRunPath\UnitTest.csv"

        @(
            "Name"
            "Type"
            "Vendor"
            "Category"
            "Recommendation"
            "Risk"
            "Reason"
            "Source"
            "Version"
            "State"
        ) | ForEach-Object {
            $csv[0].PSObject.Properties.Name |
                Should -Contain $_
        }
    }

    It "creates a default repository report path without a session" {
        $Global:ToolkitRunPath = $null

        $path = Get-ToolkitReportPath
        $expectedRoot = Join-Path $Root "Reports"

        $path |
            Should -BeLike "$expectedRoot\Run_*"

        Test-Path $path |
            Should -BeTrue
    }

    It "creates a missing report directory automatically" {
        $Global:ToolkitRunPath = Join-Path `
            $TestDrive `
            "Missing\ReportFolder"

        Save-CsvReport `
            -Name "AutomaticDirectory" `
            -Data @($Finding)

        Test-Path $Global:ToolkitRunPath |
            Should -BeTrue
    }
}

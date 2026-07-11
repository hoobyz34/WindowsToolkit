Describe "Reporting" {

    BeforeAll {

        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Models.psm1" -Force
        Import-Module "$Root\Core\Reporting.psm1" -Force

        $Global:ToolkitRunPath = Join-Path $env:TEMP "WindowsToolkit_Test"

        if (-not (Test-Path $Global:ToolkitRunPath)) {
            New-Item -ItemType Directory -Path $Global:ToolkitRunPath | Out-Null
        }

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

        $csv = Import-Csv "$Global:ToolkitRunPath\UnitTest.csv"

        $csv.Count | Should -Be 1
    }

    It "CSV contains expected columns" {

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

}

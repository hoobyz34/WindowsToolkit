Describe "Finding Model" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Models.psm1" -Force
    }

    It "New-ToolkitFinding creates an object" {

        $finding = New-ToolkitFinding `
            -Name "Test" `
            -Type "UnitTest" `
            -Vendor "OpenAI" `
            -Category "Test" `
            -Recommendation "None" `
            -Risk "Low" `
            -Reason "Unit Test" `
            -Source "Pester" `
            -Version "1.0" `
            -State "Present"

        $finding | Should -Not -BeNullOrEmpty
    }

    It "Finding contains all required properties" {

        $finding = New-ToolkitFinding `
            -Name "Test" `
            -Type "UnitTest" `
            -Vendor "OpenAI" `
            -Category "Test" `
            -Recommendation "None" `
            -Risk "Low" `
            -Reason "Unit Test" `
            -Source "Pester" `
            -Version "1.0" `
            -State "Present"

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

            $finding.PSObject.Properties.Name |
                Should -Contain $_

        }
    }

    It "Finding values are preserved" {

        $finding = New-ToolkitFinding `
            -Name "CPU" `
            -Type "Hardware" `
            -Vendor "Intel" `
            -Category "Recommended" `
            -Recommendation "Keep" `
            -Risk "Low" `
            -Reason "Required driver" `
            -Source "Discovery" `
            -Version "31.0" `
            -State "Installed"

        $finding.Name | Should -Be "CPU"
        $finding.Vendor | Should -Be "Intel"
        $finding.Recommendation | Should -Be "Keep"
        $finding.State | Should -Be "Installed"
    }

}

Describe "Correlation Engine" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Correlation.psm1" -Force
    }

    It "loads correlation rules from JSON" {
        $rules = Get-ToolkitCorrelationRules

        $rules.Count |
            Should -BeGreaterThan 0
    }

    It "correlation rules contain required fields" {
        $rules = Get-ToolkitCorrelationRules

        foreach ($rule in $rules) {
            $rule.id |
                Should -Not -BeNullOrEmpty

            $rule.name |
                Should -Not -BeNullOrEmpty

            $rule.category |
                Should -Not -BeNullOrEmpty

            $rule.recommendation |
                Should -Not -BeNullOrEmpty

            $rule.risk |
                Should -Not -BeNullOrEmpty

            $rule.reason |
                Should -Not -BeNullOrEmpty
        }
    }

    It "matches a condition by type and pattern" {
        $findings = @(
            [PSCustomObject]@{
                Name  = "Docker Desktop"
                Type  = "Software"
                State = "Installed"
            }
        )

        $condition = [PSCustomObject]@{
            type     = "Software"
            pattern  = "Docker"
            minCount = 1
        }

        Test-ToolkitCorrelationCondition `
            -Findings $findings `
            -Condition $condition |
            Should -BeTrue
    }

    It "respects minimum match counts" {
        $findings = @(
            [PSCustomObject]@{
                Name = "HP Wolf Security"
                Type = "Software"
            }
        )

        $condition = [PSCustomObject]@{
            pattern  = "HP"
            minCount = 2
        }

        Test-ToolkitCorrelationCondition `
            -Findings $findings `
            -Condition $condition |
            Should -BeFalse
    }

    It "matches state-specific conditions" {
        $findings = @(
            [PSCustomObject]@{
                Name  = "VirtualMachinePlatform"
                Type  = "WindowsFeature"
                State = "Disabled"
            }
        )

        $condition = [PSCustomObject]@{
            type         = "WindowsFeature"
            pattern      = "^VirtualMachinePlatform$"
            statePattern = "Disabled"
            minCount     = 1
        }

        Test-ToolkitCorrelationCondition `
            -Findings $findings `
            -Condition $condition |
            Should -BeTrue
    }

    It "detects Docker with Virtual Machine Platform disabled" {
        $findings = @(
            [PSCustomObject]@{
                Name           = "Docker Desktop"
                Type           = "Software"
                Vendor         = "Docker"
                Category       = "Optional"
                Recommendation = "Keep"
                Risk           = "Low"
                Reason         = "Test"
                State          = "Installed"
            }
            [PSCustomObject]@{
                Name           = "VirtualMachinePlatform"
                Type           = "WindowsFeature"
                Vendor         = "Microsoft"
                Category       = "Unknown"
                Recommendation = "Review"
                Risk           = "Unknown"
                Reason         = "Test"
                State          = "Disabled"
            }
        )

        $results = Invoke-ToolkitCorrelation `
            -Findings $findings

        $results.CorrelationId |
            Should -Contain "docker-vmp-disabled"
    }

    It "does not report the disabled rule when the feature is enabled" {
        $findings = @(
            [PSCustomObject]@{
                Name  = "Docker Desktop"
                Type  = "Software"
                State = "Installed"
            }
            [PSCustomObject]@{
                Name  = "VirtualMachinePlatform"
                Type  = "WindowsFeature"
                State = "Enabled"
            }
        )

        $results = Invoke-ToolkitCorrelation `
            -Findings $findings

        $results.CorrelationId |
            Should -Not -Contain "docker-vmp-disabled"

        $results.CorrelationId |
            Should -Contain "docker-vmp-enabled"
    }

    It "detects the Microsoft Store installation stack" {
        $findings = @(
            [PSCustomObject]@{
                Name = "Microsoft.WindowsStore"
                Type = "AppxPackage"
            }
            [PSCustomObject]@{
                Name = "Microsoft.DesktopAppInstaller"
                Type = "AppxPackage"
            }
        )

        $results = Invoke-ToolkitCorrelation `
            -Findings $findings

        $results.CorrelationId |
            Should -Contain "store-and-app-installer"
    }

    It "does not evaluate missing-package rules without Appx inventory" {
        $findings = @(
            [PSCustomObject]@{
                Name = "Intel Driver"
                Type = "Driver"
            }
        )

        $results = Invoke-ToolkitCorrelation `
            -Findings $findings

        $results.CorrelationId |
            Should -Not -Contain "store-missing"
    }

    It "detects a missing Store package after Appx inventory exists" {
        $findings = @(
            [PSCustomObject]@{
                Name = "Microsoft.WindowsTerminal"
                Type = "AppxPackage"
            }
        )

        $results = Invoke-ToolkitCorrelation `
            -Findings $findings

        $results.CorrelationId |
            Should -Contain "store-missing"
    }

    It "emits standardized correlation findings" {
        $findings = @(
            [PSCustomObject]@{
                Name  = "VirtualMachinePlatform"
                Type  = "WindowsFeature"
                State = "Enabled"
            }
        )

        $result = @(
            Invoke-ToolkitCorrelation `
                -Findings $findings
        )[0]

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
            $result.PSObject.Properties.Name |
                Should -Contain $_
        }
    }

    It "does not recursively correlate prior correlation findings" {
        $findings = @(
            [PSCustomObject]@{
                Name = "VirtualMachinePlatform"
                Type = "Correlation"
                State = "Enabled"
            }
        )

        $results = Invoke-ToolkitCorrelation `
            -Findings $findings

        $results.Count |
            Should -Be 0
    }
}

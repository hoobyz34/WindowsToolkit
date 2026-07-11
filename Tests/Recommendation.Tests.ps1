$Root = Split-Path -Parent $PSScriptRoot

$RuleFiles = @(
    "Rules.json"
    "Services.json"
    "Software.json"
    "Drivers.json"
    "AppxPackages.json"
    "Vendors.json"
)

Describe "Recommendation Data Files" {

    It "Data file <_> exists" -ForEach $RuleFiles {
        Test-Path "$Root\Data\$_" | Should -BeTrue
    }

    It "Data file <_> contains valid JSON" -ForEach $RuleFiles {
        {
            Get-Content "$Root\Data\$_" -Raw |
                ConvertFrom-Json -ErrorAction Stop
        } | Should -Not -Throw
    }
}

Describe "Recommendation Rule Routing" {

    BeforeAll {
        Import-Module "$Root\Core\Recommendation.psm1" -Force
    }

    It "uses Drivers.json for driver recommendations" {
        $result = Get-ToolkitRecommendation `
            -Text "Intel Graphics Driver" `
            -Type "Driver"

        $result.Vendor | Should -Be "Intel"
        $result.Category | Should -Be "Hardware Driver"
        $result.Recommendation | Should -Be "KEEP"
    }

    It "uses AppxPackages.json for Appx recommendations" {
        $result = Get-ToolkitRecommendation `
            -Text "Microsoft.WindowsStore" `
            -Type "AppxPackage"

        $result.Vendor | Should -Be "Microsoft"
        $result.Category | Should -Be "Required"
        $result.Recommendation | Should -Be "Keep"
        $result.Risk | Should -Be "High"
    }

    It "falls back to the general rules when no specific rule matches" {
        $result = Get-ToolkitRecommendation `
            -Text "Completely Unknown Driver Entry" `
            -Type "Driver"

        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain "Recommendation"
        $result.PSObject.Properties.Name | Should -Contain "Reason"
    }
}

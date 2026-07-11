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
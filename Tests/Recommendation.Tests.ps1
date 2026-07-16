$RuleFiles = @(
    "Rules.json"
    "Services.json"
    "Software.json"
    "Drivers.json"
    "HP.json"
    "AppxPackages.json"
    "Vendors.json"
)

Describe "Recommendation Data Files" {

    It "Data file <_> exists" -ForEach $RuleFiles {
        Test-Path "$PSScriptRoot\..\Data\$_" |
            Should -BeTrue
    }

    It "Data file <_> contains valid JSON" -ForEach $RuleFiles {
        {
            Get-Content "$PSScriptRoot\..\Data\$_" -Raw |
                ConvertFrom-Json -ErrorAction Stop
        } | Should -Not -Throw
    }
}

Describe "Recommendation Rule Schema" {

    $RecommendationFiles = @(
        "Rules.json"
        "Services.json"
        "Software.json"
        "Drivers.json"
        "HP.json"
        "AppxPackages.json"
    )

    It "<_> contains at least one rule" -ForEach $RecommendationFiles {
        $rules = @(
                Get-Content "$PSScriptRoot\..\Data\$_" -Raw |
                ConvertFrom-Json
        )

        $rules.Count |
            Should -BeGreaterThan 0
    }

    It "every rule in <_> contains a reason" -ForEach $RecommendationFiles {
        $rules = @(
                Get-Content "$PSScriptRoot\..\Data\$_" -Raw |
                ConvertFrom-Json
        )

        foreach ($rule in $rules) {
            $rule.reason |
                Should -Not -BeNullOrEmpty
        }
    }

    It "every rule in <_> contains a risk" -ForEach $RecommendationFiles {
        $rules = @(
                Get-Content "$PSScriptRoot\..\Data\$_" -Raw |
                ConvertFrom-Json
        )

        foreach ($rule in $rules) {
            $rule.risk |
                Should -Not -BeNullOrEmpty
        }
    }

    It "every rule in <_> contains a recommendation or action" -ForEach $RecommendationFiles {
        $rules = @(
                Get-Content "$PSScriptRoot\..\Data\$_" -Raw |
                ConvertFrom-Json
        )

        foreach ($rule in $rules) {
            $hasRecommendation = -not [string]::IsNullOrWhiteSpace(
                [string]$rule.recommendation
            )

            $hasAction = -not [string]::IsNullOrWhiteSpace(
                [string]$rule.action
            )

            ($hasRecommendation -or $hasAction) |
                Should -BeTrue
        }
    }

    It "every rule in <_> contains match text or patterns" -ForEach $RecommendationFiles {
        $rules = @(
                Get-Content "$PSScriptRoot\..\Data\$_" -Raw |
                ConvertFrom-Json
        )

        foreach ($rule in $rules) {
            $hasMatch = -not [string]::IsNullOrWhiteSpace(
                [string]$rule.match
            )

            $hasPatterns = @($rule.patterns).Count -gt 0

            # General profile rules are metadata-driven and may not
            # contain literal match text.
            $isProfileRule = $rule.type -eq "profile"

            ($hasMatch -or $hasPatterns -or $isProfileRule) |
                Should -BeTrue
        }
    }

    It "every explicit match mode in <_> is supported" -ForEach $RecommendationFiles {
        $rules = @(
            Get-Content "$PSScriptRoot\..\Data\$_" -Raw |
                ConvertFrom-Json
        )

        foreach ($rule in $rules | Where-Object matchMode) {
            [string]$rule.matchMode |
                Should -BeIn @("contains", "exact", "word")
        }
    }
}

Describe "Vendor Rule Schema" {

    BeforeAll {
        $Vendors = @(
            Get-Content "$PSScriptRoot\..\Data\Vendors.json" -Raw |
                ConvertFrom-Json
        )
    }

    It "contains at least one vendor" {
        $Vendors.Count |
            Should -BeGreaterThan 0
    }

    It "every vendor contains a name" {
        foreach ($vendor in $Vendors) {
            $vendor.name |
                Should -Not -BeNullOrEmpty
        }
    }

    It "every vendor contains at least one pattern" {
        foreach ($vendor in $Vendors) {
            @($vendor.patterns).Count |
                Should -BeGreaterThan 0
        }
    }

    It "every explicit vendor match mode is supported" {
        foreach ($vendor in $script:VendorRules) {
            if ($vendor.matchMode) {
                [string]$vendor.matchMode |
                    Should -BeIn @("contains", "exact", "word")
            }
        }
    }

    It "does not classify ELAN or embedded HP text as vendor HP" -ForEach @(
        "ELAN Touchpad Component",
        "MyPHPService",
        "AlphaHPBeta"
    ) {
        Get-ToolkitVendor -Text $_ | Should -Not -Be "HP"
    }
}

Describe "Recommendation Rule Routing" {

    BeforeAll {
        Import-Module "$PSScriptRoot\..\Core\Recommendation.psm1" -Force
    }

    It "uses Drivers.json for driver recommendations" {
        $result = Get-ToolkitRecommendation `
            -Text "Intel Graphics Driver" `
            -Type "Driver"

        $result.Vendor |
            Should -Be "Intel"

        $result.Category |
            Should -Be "Hardware Driver"

        $result.Recommendation |
            Should -Be "KEEP"
    }

    It "uses AppxPackages.json for Appx recommendations" {
        $result = Get-ToolkitRecommendation `
            -Text "Microsoft.WindowsStore" `
            -Type "AppxPackage"

        $result.Vendor |
            Should -Be "Microsoft"

        $result.Category |
            Should -Be "Required"

        $result.Recommendation |
            Should -Be "Keep"

        $result.Risk |
            Should -Be "High"
    }

    It "returns a safe review result when no rule matches" {
        $result = Get-ToolkitRecommendation `
            -Text "Completely Unknown Driver Entry" `
            -Type "Driver"

        $result.Recommendation |
            Should -Be "Review"

        $result.Reason |
            Should -Not -BeNullOrEmpty
    }

    It "honors explicit word matching without substring collisions" {
        Test-ToolkitRuleTextMatch `
            -Text "ELAN Touchpad Component" `
            -Pattern "LAN" `
            -Mode "word" |
            Should -BeFalse

        Test-ToolkitRuleTextMatch `
            -Text "HP LAN Switching Service" `
            -Pattern "LAN" `
            -Mode "word" |
            Should -BeTrue
    }
}

Describe "Profile Recommendation Boundaries" {

    BeforeAll {
        Import-Module "$PSScriptRoot\..\Core\Recommendation.psm1" -Force
    }

    It "keeps an exact alwaysKeep profile name" -ForEach @(
        "OneDrive"
        "Driver Easy"
    ) {
        $result = Get-ToolkitRecommendation `
            -Name $_ `
            -Text "Unrelated startup command" `
            -Type "general"

        $result.Recommendation |
            Should -Be "KEEP"
    }

    It "does not apply profile preferences from unrelated <Type> text" -ForEach @(
        "general"
        "service"
        "software"
        "driver"
    ) {
        $result = Get-ToolkitRecommendation `
            -Name "Contoso Startup Helper" `
            -Text "C:\\Program Files\\OneDrive\\Driver Easy\\helper.exe" `
            -Type $_

        $result.Recommendation |
            Should -Be "Review"
    }

    It "does not retain OneDrive or Driver Easy text rules" {
        $ruleFiles = @(
            "Rules.json"
            "Software.json"
        )

        foreach ($ruleFile in $ruleFiles) {
            $rules = @(
                Get-Content "$PSScriptRoot\..\Data\$ruleFile" -Raw |
                    ConvertFrom-Json
            )

            $rules.match |
                Should -Not -Contain "OneDrive"

            $rules.match |
                Should -Not -Contain "Driver Easy"
        }
    }

    It "does not apply a profile preference to a partial finding name" -ForEach @(
        "OneDrive Helper"
        "Driver Easy Updater"
    ) {
        $result = Get-ToolkitRecommendation `
            -Name $_ `
            -Text "Unrelated startup command" `
            -Type "general"

        $result.Recommendation |
            Should -Be "Review"
    }
}

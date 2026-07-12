$Root = Split-Path -Parent $PSScriptRoot

$AnalyzerFiles = @(
    "Audit.ps1"
    "Services.ps1"
    "Startup.ps1"
    "Software.ps1"
    "HP.ps1"
    "Drivers.ps1"
    "ScheduledTasks.ps1"
    "WindowsFeatures.ps1"
    "AppxPackages.ps1"
    "Summary.ps1"
    "Dashboard.ps1"
)

Describe "Analyzer Module Integrity" {

    It "Modules/<_> exists" -ForEach $AnalyzerFiles {
        Test-Path "$Root\Modules\$_" |
            Should -BeTrue
    }

    It "Modules/<_> is not empty" -ForEach $AnalyzerFiles {
        $path = "$Root\Modules\$_"

        (Get-Item $path).Length |
            Should -BeGreaterThan 0

        Get-Content $path -Raw |
            Should -Not -BeNullOrEmpty
    }

    It "Modules/<_> contains valid PowerShell syntax" -ForEach $AnalyzerFiles {
        $path = "$Root\Modules\$_"

        $tokens = $null
        $errors = $null

        [System.Management.Automation.Language.Parser]::ParseFile(
            $path,
            [ref]$tokens,
            [ref]$errors
        ) | Out-Null

        @($errors).Count |
            Should -Be 0
    }
}

Describe "Installed Software Analyzer Structure" {

    BeforeAll {
        $SoftwareModulePath = "$Root\Modules\Software.ps1"
        $SoftwareModule = Get-Content `
            -Path $SoftwareModulePath `
            -Raw
    }

    It "uses the installed-software discovery function" {
        $SoftwareModule |
            Should -Match "Get-ToolkitInstalledSoftware"
    }

    It "uses the recommendation engine" {
        $SoftwareModule |
            Should -Match "Get-ToolkitRecommendation"
    }

    It "creates standardized findings" {
        $SoftwareModule |
            Should -Match "New-ToolkitFinding"
    }

    It "exports through the reporting engine" {
        $SoftwareModule |
            Should -Match "Save-CsvReport"
    }

    It "does not perform software removal" {
        $SoftwareModule |
            Should -Not -Match "Uninstall-Package"

        $SoftwareModule |
            Should -Not -Match "Remove-AppxPackage"

        $SoftwareModule |
            Should -Not -Match "msiexec.+/x"
    }
}

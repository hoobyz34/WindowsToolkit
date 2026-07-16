Describe "Core Modules" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot
    }

    It "Discovery module imports" {
        {
            Import-Module "$Root\Core\Discovery.psm1" -Force
        } | Should -Not -Throw
    }

    It "Models module imports" {
        {
            Import-Module "$Root\Core\Models.psm1" -Force
        } | Should -Not -Throw
    }

    It "Recommendation module imports" {
        {
            Import-Module "$Root\Core\Recommendation.psm1" -Force
        } | Should -Not -Throw
    }

    It "Reporting module imports" {
        {
            Import-Module "$Root\Core\Reporting.psm1" -Force
        } | Should -Not -Throw
    }

    It "Optimizer module imports" {
        {
            Import-Module "$Root\Core\Optimizer.psm1" -Force
        } | Should -Not -Throw
    }

}

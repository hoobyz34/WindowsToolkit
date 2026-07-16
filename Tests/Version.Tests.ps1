Describe "Version Module" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot
        Import-Module "$Root\Core\Version.psm1" -Force
    }

    It "imports successfully" {
        {
            Import-Module "$Root\Core\Version.psm1" -Force
        } | Should -Not -Throw
    }

    It "returns the current release version" {
        Get-ToolkitVersion | Should -Be "0.4.0"
    }

    It "stores the version globally for the console header" {
        $Global:ToolkitVersion | Should -Be "0.4.0"
    }
}

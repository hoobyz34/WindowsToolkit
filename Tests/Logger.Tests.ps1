Describe "Logger and Session Initialization" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Logger.psm1" -Force
    }

    BeforeEach {
        $Global:ToolkitRoot = $null
        $Global:ToolkitRunPath = $null
        $Global:ToolkitLogPath = $null
        $Global:ToolkitTimestamp = "2000-01-01_00-00-00"

        Mock New-Item -ModuleName Logger {
            [PSCustomObject]@{
                FullName = $Path
            }
        }

        Mock Start-Transcript -ModuleName Logger {
            $null
        }

        Mock Write-Log -ModuleName Logger {
            $null
        }
    }

    It "sets the toolkit root to the repository directory" {
        Initialize-ToolkitSession

        $Global:ToolkitRoot |
            Should -Be $Root
    }

    It "places reports inside the repository Reports directory" {
        Initialize-ToolkitSession

        $Expected = Join-Path `
            $Root `
            "Reports\Run_2000-01-01_00-00-00"

        $Global:ToolkitRunPath |
            Should -Be $Expected
    }

    It "places logs inside the repository Logs directory" {
        Initialize-ToolkitSession

        $Expected = Join-Path `
            $Root `
            "Logs\Run_2000-01-01_00-00-00.log"

        $Global:ToolkitLogPath |
            Should -Be $Expected
    }

    It "creates both report and log directories" {
        Initialize-ToolkitSession

        Should -Invoke New-Item `
            -ModuleName Logger `
            -Times 2
    }

    It "starts a transcript for the current session" {
        Initialize-ToolkitSession

        Should -Invoke Start-Transcript `
            -ModuleName Logger `
            -Times 1 `
            -ParameterFilter {
                $Path -eq $Global:ToolkitLogPath
            }
    }
}

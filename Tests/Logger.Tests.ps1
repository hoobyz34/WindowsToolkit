Describe "Logger and Session Initialization" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Logger.psm1" -Force
    }

    BeforeEach {
        $Global:ToolkitRoot = $null
        $Global:ToolkitRunPath = $null
        $Global:ToolkitLogPath = $null
        $Global:ToolkitTimestamp = $null

        Mock New-Item -ModuleName Logger {
            [PSCustomObject]@{
                FullName = $Path
            }
        }

        Mock Start-Transcript -ModuleName Logger {
            $null
        }

        Mock Stop-Transcript -ModuleName Logger {
            $null
        }

        Mock Write-Log -ModuleName Logger {
            $null
        }
    }

    It "sets the toolkit root to the repository directory" {
        Initialize-ToolkitSession `
            -Timestamp "2000-01-01_00-00-00"

        $Global:ToolkitRoot |
            Should -Be $Root
    }

    It "uses the supplied timestamp for deterministic session paths" {
        Initialize-ToolkitSession `
            -Timestamp "2000-01-01_00-00-00"

        $Global:ToolkitTimestamp |
            Should -Be "2000-01-01_00-00-00"
    }

    It "places reports inside the repository Reports directory" {
        Initialize-ToolkitSession `
            -Timestamp "2000-01-01_00-00-00"

        $Expected = Join-Path `
            $Root `
            "Reports\Run_2000-01-01_00-00-00"

        $Global:ToolkitRunPath |
            Should -Be $Expected
    }

    It "places logs inside the repository Logs directory" {
        Initialize-ToolkitSession `
            -Timestamp "2000-01-01_00-00-00"

        $Expected = Join-Path `
            $Root `
            "Logs\Run_2000-01-01_00-00-00.log"

        $Global:ToolkitLogPath |
            Should -Be $Expected
    }

    It "creates both report and log directories" {
        Initialize-ToolkitSession `
            -Timestamp "2000-01-01_00-00-00"

        Should -Invoke New-Item `
            -ModuleName Logger `
            -Times 2
    }

    It "starts a transcript for the current session" {
        Initialize-ToolkitSession `
            -Timestamp "2000-01-01_00-00-00"

        Should -Invoke Start-Transcript `
            -ModuleName Logger `
            -Times 1 `
            -ParameterFilter {
                $Path -eq $Global:ToolkitLogPath
            }
    }

    It "stops the transcript when the session ends" {
        Stop-ToolkitSession

        Should -Invoke Stop-Transcript `
            -ModuleName Logger `
            -Times 1
    }
}

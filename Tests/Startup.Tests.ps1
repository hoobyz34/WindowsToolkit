Describe "Startup Analyzer" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot

        Import-Module "$Root\Core\Logger.psm1" -Force
        Import-Module "$Root\Core\Console.psm1" -Force
        Import-Module "$Root\Core\Models.psm1" -Force
        Import-Module "$Root\Core\Discovery.psm1" -Force
        Import-Module "$Root\Core\Recommendation.psm1" -Force
        Import-Module "$Root\Core\Reporting.psm1" -Force
    }

    BeforeEach {
        $Global:StartupAnalyzerReportName = $null
        $Global:StartupAnalyzerReportedFindings = @()

        Mock Write-Section {}
        Mock Write-Success {}
        Mock Get-ToolkitStartupCommands {
            [PSCustomObject]@{
                Name = "OneDrive"
                Command = "OneDrive.exe /background"
                Location = "HKCU\\Run"
                User = "ToolkitUser"
                Setting = "Enabled"
            }
        }
        Mock Get-ToolkitScheduledTasks {
            [PSCustomObject]@{
                TaskPath = "\\"
                TaskName = "HP Insights Startup"
                Author = "HP"
                Triggers = "AtLogOn"
            }
            [PSCustomObject]@{
                TaskPath = "\\"
                TaskName = "Daily Task"
                Author = "Microsoft"
                Triggers = "Daily"
            }
        }
        Mock Get-ToolkitServices {
            [PSCustomObject]@{
                Name = "WinDefend"
                DisplayName = "Microsoft Defender Antivirus Service"
                PathName = "C:\\Windows\\System32\\MsMpEng.exe"
                StartMode = "Auto"
                State = "Running"
            }
            [PSCustomObject]@{
                Name = "ManualService"
                DisplayName = "Manual Service"
                PathName = "C:\\Manual.exe"
                StartMode = "Manual"
                State = "Stopped"
            }
        }
        Mock Save-CsvReport {
            param($Name, $Data)

            $Global:StartupAnalyzerReportName = $Name
            $Global:StartupAnalyzerReportedFindings = @($Data)
            Join-Path $TestDrive "$Name.csv"
        }
    }

    It "uses discovery, recommendation, findings, and reporting" {
        & "$Root\Modules\Startup.ps1"

        Should -Invoke Get-ToolkitStartupCommands -Times 1 -Exactly
        Should -Invoke Get-ToolkitScheduledTasks -Times 1 -Exactly
        Should -Invoke Get-ToolkitServices -Times 1 -Exactly
        Should -Invoke Save-CsvReport -Times 1 -Exactly

        $Global:StartupAnalyzerReportName | Should -Be "Startup_Analyzer"
        $Global:StartupAnalyzerReportedFindings.Count | Should -Be 3
    }

    It "creates standardized findings with JSON-backed recommendations" {
        & "$Root\Modules\Startup.ps1"

        $startupFinding = $Global:StartupAnalyzerReportedFindings |
            Where-Object Name -eq "OneDrive"
        $taskFinding = $Global:StartupAnalyzerReportedFindings |
            Where-Object Name -eq "\\HP Insights Startup"
        $serviceFinding = $Global:StartupAnalyzerReportedFindings |
            Where-Object Name -eq "Microsoft Defender Antivirus Service"

        $startupFinding.Type | Should -Be "Startup Command"
        $startupFinding.Recommendation | Should -Be "KEEP"
        $startupFinding.Source | Should -Be "HKCU\\Run"
        $taskFinding.Recommendation | Should -Be "Review / likely disable"
        $serviceFinding.Recommendation | Should -Be "KEEP"
        $serviceFinding.Risk | Should -Be "Critical"

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
            $startupFinding.PSObject.Properties.Name |
                Should -Contain $_
        }
    }

    AfterAll {
        Remove-Variable `
            -Name StartupAnalyzerReportName, StartupAnalyzerReportedFindings `
            -Scope Global `
            -ErrorAction SilentlyContinue
    }
}

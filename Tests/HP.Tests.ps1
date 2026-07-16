Describe "HP Analyzer" {

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
        $Global:HPAnalyzerReportName = $null
        $Global:HPAnalyzerReportedFindings = @()

        Mock Write-Section {}
        Mock Write-Success {}
        Mock Get-ToolkitServices {
            [PSCustomObject]@{
                Name = "HPHotkeyService"
                DisplayName = "HP Hotkey Service"
                PathName = "C:\\Program Files\\HP\\Hotkey.exe"
                State = "Running"
            }
            [PSCustomObject]@{
                Name = "UnrelatedService"
                DisplayName = "Microsoft Update Service"
                PathName = "C:\\Windows\\update.exe"
                State = "Running"
            }
        }
        Mock Get-ToolkitInstalledSoftware {
            [PSCustomObject]@{
                DisplayName = "HP Insights"
                Publisher = "HP"
                DisplayVersion = "1.0"
                InstallLocation = "C:\\Program Files\\HP\\Insights"
                PSPath = "HKLM:\\Software\\HP\\Insights"
            }
        }
        Mock Get-ToolkitDrivers {
            [PSCustomObject]@{
                DeviceName = "HP Unknown Device"
                Manufacturer = "HP"
                DriverProviderName = "HP"
                InfName = "hpdevice.inf"
                DriverVersion = "1.2.3"
            }
        }
        Mock Get-ToolkitScheduledTasks {
            [PSCustomObject]@{
                TaskPath = "\\HP\\"
                TaskName = "HP Diagnostics"
                Author = "HP"
                State = "Ready"
            }
        }
        Mock Save-CsvReport {
            param($Name, $Data)

            $Global:HPAnalyzerReportName = $Name
            $Global:HPAnalyzerReportedFindings = @($Data)
            Join-Path $TestDrive "$Name.csv"
        }
    }

    It "routes HP sources through JSON recommendations" {
        $hotkey = Get-ToolkitRecommendation `
            -Text "HP Hotkey Service HP" `
            -Type "HP"
        $telemetry = Get-ToolkitRecommendation `
            -Text "HP Insights" `
            -Type "HP"
        $unknown = Get-ToolkitRecommendation `
            -Text "HP Unclassified Component" `
            -Type "HP"
        $elan = Get-ToolkitRecommendation `
            -Text "ELAN Touchpad Component HP" `
            -Type "HP"

        $hotkey.Category | Should -Be "Required"
        $hotkey.Recommendation | Should -Be "KEEP"
        $telemetry.Category | Should -Be "Telemetry"
        $telemetry.Recommendation | Should -Be "Review / likely disable"
        $unknown.Category | Should -Be "Unknown"
        $unknown.Recommendation | Should -Be "Review"
        $elan.Category | Should -Be "Unknown"
        $elan.Recommendation | Should -Be "Review"
    }

    It "uses explicit HP word matching for collision-prone rules" -ForEach @(
        @{ Text = "ELAN Touchpad Component HP"; Match = "LAN" }
        @{ Text = "HP PLANar Component"; Match = "LAN" }
        @{ Text = "HP Buttoned Component"; Match = "Button" }
        @{ Text = "HP Audiophile Component"; Match = "Audio" }
        @{ Text = "HP Wolfgang Component"; Match = "Wolf" }
    ) {
        $result = Get-ToolkitRecommendation `
            -Text $Text `
            -Type "HP"

        $result.Category | Should -Be "Unknown"
        $result.Recommendation | Should -Be "Review"
    }

    It "creates standardized findings for HP discovery sources and reports them" {
        & "$Root\Modules\HP.ps1"

        Should -Invoke Get-ToolkitServices -Times 1 -Exactly
        Should -Invoke Get-ToolkitInstalledSoftware -Times 1 -Exactly
        Should -Invoke Get-ToolkitDrivers -Times 1 -Exactly
        Should -Invoke Get-ToolkitScheduledTasks -Times 1 -Exactly
        Should -Invoke Save-CsvReport -Times 1 -Exactly

        $Global:HPAnalyzerReportName | Should -Be "HP_Analyzer"
        $Global:HPAnalyzerReportedFindings.Count | Should -Be 4

        $hotkey = $Global:HPAnalyzerReportedFindings |
            Where-Object Name -eq "HP Hotkey Service"
        $insights = $Global:HPAnalyzerReportedFindings |
            Where-Object Name -eq "HP Insights"
        $task = $Global:HPAnalyzerReportedFindings |
            Where-Object Name -eq "\\HP\\HP Diagnostics"

        $hotkey.Type | Should -Be "HP Service"
        $hotkey.Category | Should -Be "Required"
        $insights.Type | Should -Be "HP Software"
        $insights.Category | Should -Be "Telemetry"
        $task.Type | Should -Be "HP Scheduled Task"

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
            $hotkey.PSObject.Properties.Name |
                Should -Contain $_
        }
    }

    It "reports HP findings when discovered source metadata is blank" {
        Mock Get-ToolkitDrivers {
            [PSCustomObject]@{
                DeviceName = "HP Source-Less Device"
                Manufacturer = "HP"
                DriverProviderName = "HP"
                InfName = ""
                DriverVersion = "1.2.3"
            }
        }

        {
            & "$Root\Modules\HP.ps1"
        } | Should -Not -Throw

        $driver = $Global:HPAnalyzerReportedFindings |
            Where-Object Name -eq "HP Source-Less Device"

        Should -Invoke Save-CsvReport -Times 1 -Exactly
        $driver | Should -Not -BeNullOrEmpty
        $driver.Source | Should -Be "Source unavailable"
    }

    It "does not admit ELAN as an HP source through a LAN substring collision" {
        Mock Get-ToolkitServices {
            [PSCustomObject]@{
                Name        = "ELANTouchpadService"
                DisplayName = "ELAN Touchpad Component"
                PathName    = "C:\Windows\System32\ELAN.exe"
                State       = "Running"
            }
        }
        Mock Get-ToolkitInstalledSoftware { @() }
        Mock Get-ToolkitDrivers { @() }
        Mock Get-ToolkitScheduledTasks { @() }

        & "$Root\Modules\HP.ps1"

        $Global:HPAnalyzerReportedFindings.Count | Should -Be 0
    }

    It "uses a valid HP JSON rule file" {
        Test-Path "$Root\Data\HP.json" | Should -BeTrue

        {
            Get-Content "$Root\Data\HP.json" -Raw |
                ConvertFrom-Json -ErrorAction Stop
        } | Should -Not -Throw

        $rules = Get-Content "$Root\Data\HP.json" -Raw |
            ConvertFrom-Json
        foreach ($rule in $rules) {
            $rule.matchMode | Should -Be "word"
        }
    }

    AfterAll {
        Remove-Variable `
            -Name HPAnalyzerReportName, HPAnalyzerReportedFindings `
            -Scope Global `
            -ErrorAction SilentlyContinue
    }
}

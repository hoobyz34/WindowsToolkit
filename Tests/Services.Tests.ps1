Describe "Service Discovery and Reporting" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot
        Import-Module "$Root\Core\Discovery.psm1" -Force
        Import-Module "$Root\Core\Models.psm1" -Force
        Import-Module "$Root\Core\Recommendation.psm1" -Force
        Import-Module "$Root\Core\Reporting.psm1" -Force
        Import-Module "$Root\Core\Console.psm1" -Force
    }

    BeforeEach {
        $Global:ServiceAnalyzerFindings = @()

        Mock Get-CimInstance -ModuleName Discovery {
            [PSCustomObject]@{
                Name        = "HpTouchpointAnalyticsService"
                DisplayName = "HP Insights Analytics"
                PathName    = "C:\Windows\HP\TouchpointAnalyticsClientService.exe"
                State       = "Running"
                StartMode   = "Auto"
                StartName   = "LocalSystem"
                ServiceType = "Own Process"
            }
        }
        Mock Get-Service -ModuleName Discovery {
            [PSCustomObject]@{
                Name              = "HpTouchpointAnalyticsService"
                DisplayName       = "HP Insights Analytics"
                StartType         = "Automatic"
                ServicesDependedOn = @(
                    [PSCustomObject]@{ Name = "rpcss" }
                    [PSCustomObject]@{ Name = "ProfSvc" }
                )
                DependentServices = @()
            }
        }
        Mock Get-ItemProperty -ModuleName Discovery {
            $result = [PSCustomObject]@{
                FailureActionsOnNonCrashFailures = 1
            }
            $result |
                Add-Member `
                    -NotePropertyName FailureActions `
                    -NotePropertyValue ([byte[]](1, 2, 3, 4))
            $result
        }
        Mock Get-Item -ModuleName Discovery {
            [PSCustomObject]@{
                FullName      = "C:\Windows\HP\TouchpointAnalyticsClientService.exe"
                PSIsContainer = $false
                VersionInfo   = [PSCustomObject]@{
                    CompanyName = "HP Inc."
                    ProductName = "HP Insights Analytics"
                }
            }
        }
        Mock Get-AuthenticodeSignature -ModuleName Discovery {
            [PSCustomObject]@{
                Status            = "Valid"
                SignerCertificate = [PSCustomObject]@{
                    Subject = "CN=Microsoft Windows Hardware Compatibility Publisher, O=Microsoft Corporation"
                }
            }
        }
        Mock Write-Section {}
        Mock Write-Success {}
        Mock Save-CsvReport {
            param($Name, $Data)

            $Global:ServiceAnalyzerFindings = @($Data)
            Join-Path $TestDrive "$Name.csv"
        }
    }

    It "captures the exact HP Insights Analytics service before-state metadata" {
        $service = @(Get-ToolkitServices)[0]
        $recovery = $service.RecoveryConfiguration |
            ConvertFrom-Json

        $service.Name | Should -Be "HpTouchpointAnalyticsService"
        $service.DisplayName | Should -Be "HP Insights Analytics"
        $service.State | Should -Be "Running"
        $service.StartupType | Should -Be "Automatic"
        @($service.Dependencies | ConvertFrom-Json) |
            Should -Be @("ProfSvc", "rpcss")
        @($service.DependentServices | ConvertFrom-Json).Count |
            Should -Be 0
        $service.StartName | Should -Be "LocalSystem"
        $service.ServiceType | Should -Be "Own Process"
        ($service.DelayedAutoStartConfiguration | ConvertFrom-Json).Present |
            Should -BeFalse
        $recovery.FailureActionsPresent | Should -BeTrue
        $recovery.FailureActionsBase64 | Should -Be "AQIDBA=="
        $recovery.FailureActionsOnNonCrashFailures | Should -Be "1"
    }

    It "reports exact service identity and reversible snapshot fields" {
        Mock Import-Module {}

        & "$Root\Modules\Services.ps1"

        $finding = $Global:ServiceAnalyzerFindings |
            Where-Object Name -eq "HP Insights Analytics"

        $finding | Should -Not -BeNullOrEmpty
        $finding.ServiceName | Should -Be "HpTouchpointAnalyticsService"
        $finding.ServiceDisplayName | Should -Be "HP Insights Analytics"
        $finding.StartupType | Should -Be "Automatic"
        $finding.Dependencies | Should -Not -BeNullOrEmpty
        $finding.DependentServices | Should -Be "[]"
        $finding.ServiceStartName | Should -Be "LocalSystem"
        $finding.ServiceType | Should -Be "Own Process"
        $finding.ExecutableCompany | Should -Be "HP Inc."
        $finding.ExecutableProduct | Should -Be "HP Insights Analytics"
        $finding.ExecutableSignatureStatus | Should -Be "Valid"
        $finding.ExecutableSignerSubject |
            Should -Match "Microsoft Windows Hardware Compatibility Publisher"
        $finding.RecoveryConfiguration | Should -Not -BeNullOrEmpty
        $finding.Category | Should -Be "Telemetry"
        $finding.Recommendation | Should -Be "Review / likely disable"
    }

    It "rejects wildcard, path traversal, and mismatched supplied identities" {
        {
            Get-ToolkitServiceInventoryRecord -Name "HpTouchpoint*"
        } | Should -Throw "*safe literal identity*"

        {
            Get-ToolkitServiceRecoveryConfiguration `
                -ServiceName "HpTouchpointAnalyticsService\..\EventLog"
        } | Should -Throw "*safe literal registry-key leaf*"

        {
            Get-ToolkitServiceInventoryRecord `
                -Name "HpTouchpointAnalyticsService" `
                -CimService ([PSCustomObject]@{
                    Name = "EventLog"
                })
        } | Should -Throw "*does not match*"
    }

    It "keeps read-only inventory available when executable metadata is unavailable" {
        Mock Get-Item -ModuleName Discovery {
            throw "Mock missing executable"
        }

        $service = Get-ToolkitServiceInventoryRecord `
            -Name "HpTouchpointAnalyticsService" `
            -CimService ([PSCustomObject]@{
                Name        = "HpTouchpointAnalyticsService"
                DisplayName = "HP Insights Analytics"
                PathName    = "C:\Missing\TouchpointAnalyticsClientService.exe"
                State       = "Running"
                StartMode   = "Auto"
                StartName   = "LocalSystem"
                ServiceType = "Own Process"
            }) `
            -IncludeExecutableIdentity

        $service.Name | Should -Be "HpTouchpointAnalyticsService"
        $service.ExecutablePath | Should -Be ""
        $service.ExecutableSignatureStatus | Should -Be ""
    }

    It "contains no service mutation commands in discovery or reporting" {
        $text = @(
            Get-Content "$Root\Core\Discovery.psm1" -Raw
            Get-Content "$Root\Modules\Services.ps1" -Raw
        ) -join "`n"

        foreach ($command in @(
            "Set-Service",
            "Start-Service",
            "Stop-Service",
            "Restart-Service",
            "New-ItemProperty",
            "Remove-ItemProperty",
            "sc.exe config",
            "sc.exe failure"
        )) {
            $text | Should -Not -Match [regex]::Escape($command)
        }
    }

    AfterAll {
        Remove-Variable `
            -Name ServiceAnalyzerFindings `
            -Scope Global `
            -ErrorAction SilentlyContinue
    }
}

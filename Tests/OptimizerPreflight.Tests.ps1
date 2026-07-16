Describe "Safe Optimizer Preflight and Rollback Manifests" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot
        Import-Module "$Root\Core\Models.psm1" -Force
        Import-Module "$Root\Core\Optimizer.psm1" -Force
        Import-Module "$Root\Core\Reporting.psm1" -Force

        $ReadyEnvironment = [PSCustomObject]@{
            IsWindowsPlatform       = $true
            IsAdministrator        = $true
            RestorePointCapability = "Available"
            RestorePointReady      = $true
        }

        function New-TestPlanEntry {
            param(
                [string]$Name = "HP Telemetry Task",
                [string]$Type = "ScheduledTask",
                [AllowEmptyString()][string]$State = "Ready",
                [string]$ActionId = "review-likely-disable",
                [string]$Category = "Telemetry",
                [string]$Risk = "Low",
                [string]$Vendor = "HP",
                [string]$Source = "\HP\",
                [string]$ReportFile = "ScheduledTasks_Report.csv",
                [bool]$RequiresConfirmation = $true
            )

            return New-ToolkitOptimizationPlanEntry `
                -PlanId "OP-test-plan" `
                -SourceFindingId "TF-test-finding" `
                -SourceFinding "${Type}: $Name" `
                -SourceName $Name `
                -SourceType $Type `
                -SourceVersion "1.0" `
                -ProposedAction "Review as a potential future optimization" `
                -ActionId $ActionId `
                -CurrentState $State `
                -Risk $Risk `
                -Reason "Test plan entry." `
                -Confidence "High" `
                -Category $Category `
                -Vendor $Vendor `
                -Recommendation "Review / likely disable" `
                -Source $Source `
                -ReportFile $ReportFile `
                -RequiresConfirmation $RequiresConfirmation `
                -ConfirmationRequirement "Explicit confirmation is required." `
                -PlanStatus "Pending Review"
        }

        function New-TestServicePlanEntry {
            param(
                [string]$ServiceName = "HpTouchpointAnalyticsService",
                [string]$DisplayName = "HP Insights Analytics",
                [string]$StartupType = "Automatic",
                [string]$State = "Running",
                [string]$Dependencies = '["ProfSvc","rpcss"]',
                [string]$DependentServices = '[]',
                [string]$ServicePath = "C:\Windows\System32\DriverStore\FileRepository\hpanalyticscomp.inf_test\x64\TouchpointAnalyticsClientService.exe",
                [string]$ServiceStartName = "LocalSystem",
                [string]$ServiceType = "Own Process",
                [string]$DelayedAutoStartConfiguration = '{"Present":false,"Value":"0"}',
                [string]$ExecutableCompany = "HP Inc.",
                [string]$ExecutableProduct = "HP Insights Analytics",
                [string]$ExecutableSignatureStatus = "Valid",
                [string]$ExecutableSignerSubject = "CN=Microsoft Windows Hardware Compatibility Publisher, O=Microsoft Corporation",
                [string]$RecoveryConfiguration = '{"FailureActionsPresent":true,"FailureActionsBase64":"gFEBAAEAAAABAAAAAwAAABQAAAABAAAAMHUAAAEAAABg6gAAAQAAAJBfAQA=","FailureActionsOnNonCrashFailuresPresent":false,"FailureActionsOnNonCrashFailures":"","FailureCommandPresent":false,"FailureCommand":"","RebootMessagePresent":false,"RebootMessage":""}'
            )

            $finding = New-ToolkitFinding `
                -Name $DisplayName `
                -Type "Service" `
                -Vendor "HP" `
                -Category "Telemetry" `
                -Recommendation "Review / likely disable" `
                -Risk "Low" `
                -Reason "HP analytics telemetry service." `
                -Source "Windows Service" `
                -State $State `
                -ServiceName $ServiceName `
                -ServiceDisplayName $DisplayName `
                -StartupType $StartupType `
                -ServicePath $ServicePath `
                -ServiceStartName $ServiceStartName `
                -ServiceType $ServiceType `
                -DelayedAutoStartConfiguration $DelayedAutoStartConfiguration `
                -Dependencies $Dependencies `
                -DependentServices $DependentServices `
                -ExecutablePath $ServicePath `
                -ExecutableCompany $ExecutableCompany `
                -ExecutableProduct $ExecutableProduct `
                -ExecutableSignatureStatus $ExecutableSignatureStatus `
                -ExecutableSignerSubject $ExecutableSignerSubject `
                -RecoveryConfiguration $RecoveryConfiguration
            $finding |
                Add-Member `
                    -NotePropertyName ReportFile `
                    -NotePropertyValue "Service_Analyzer.csv"

            return ConvertTo-ToolkitOptimizationPlanEntry -Finding $finding
        }
    }

    BeforeEach {
        $Global:ToolkitRunPath = Join-Path $TestDrive "OptimizerPreflightReports"
    }

    It "defines complete preflight and operation policy data" {
        $rules = Get-ToolkitOptimizationActionRules

        foreach ($action in @($rules.protectedAction) + @($rules.actions) + @($rules.defaultAction)) {
            $action.preflight | Should -Not -BeNullOrEmpty
            $action.preflight.isCandidate | Should -BeOfType ([bool])
            $action.preflight.requiresCurrentState | Should -BeOfType ([bool])
            $action.preflight.requiresRestorePoint | Should -BeOfType ([bool])
        }

        $rules.operationProfiles.Count | Should -BeGreaterThan 0
        $rules.defaultOperationProfile.reversibilityStatement |
            Should -Not -BeNullOrEmpty
    }

    It "emits one standardized preflight result for every plan entry" {
        $plan = @(
            New-TestPlanEntry
            New-TestPlanEntry -Name "Second Startup Helper"
        )

        $results = @(
            New-ToolkitOptimizationPreflight `
                -PlanEntries $plan `
                -Environment $ReadyEnvironment
        )

        $results.Count | Should -Be 2
        @(
            "PreflightId", "PlanId", "ActionId", "EligibilityStatus",
            "CurrentStateValidationResult", "SafetyPolicyResult",
            "AdministratorRequired", "RestorePointCapability", "Reasons",
            "Remediation"
        ) | ForEach-Object {
            $results[0].PSObject.Properties.Name | Should -Contain $_
        }
    }

    It "marks a reversible action eligible when all prerequisites are ready" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (New-TestPlanEntry) `
            -Environment $ReadyEnvironment

        $result.EligibilityStatus | Should -Be "Eligible"
        $result.IsEligible | Should -BeTrue
        $result.IsBlocked | Should -BeFalse
        $result.CurrentStateValidationResult | Should -Be "Valid"
        $result.SafetyPolicyResult | Should -Be "Allowed"
        $result.AdministratorReady | Should -BeTrue
        $result.RestorePointReady | Should -BeTrue
    }

    It "retains explicit confirmation-required status for eligible actions" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (New-TestPlanEntry) `
            -Environment $ReadyEnvironment

        $result.Status | Should -Be "Confirmation Required"
        $result.ConfirmationRequired | Should -BeTrue
        $result.ConfirmationStatus | Should -Be "Required"
    }

    It "blocks candidate actions that omit explicit confirmation" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (New-TestPlanEntry -RequiresConfirmation $false) `
            -Environment $ReadyEnvironment

        $result.Status | Should -Be "Blocked"
        $result.Reasons | Should -Match "does not require explicit confirmation"
        $result.Remediation | Should -Match "explicit confirmation requirement"
    }

    It "blocks an action when administrator privileges are unavailable" {
        $environment = [PSCustomObject]@{
            IsWindowsPlatform       = $true
            IsAdministrator        = $false
            RestorePointCapability = "Available"
            RestorePointReady      = $true
        }

        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (New-TestPlanEntry) `
            -Environment $environment

        $result.Status | Should -Be "Blocked"
        $result.AdministratorRequired | Should -BeTrue
        $result.AdministratorReady | Should -BeFalse
        $result.Reasons | Should -Match "Administrator privileges"
        $result.Remediation | Should -Match "elevated session"
    }

    It "blocks an action when current state is missing" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (New-TestPlanEntry -State "") `
            -Environment $ReadyEnvironment

        $result.Status | Should -Be "Blocked"
        $result.CurrentStateValidationResult | Should -Be "Missing"
        $result.Remediation | Should -Match "populated State value"
    }

    It "blocks protected components even when a candidate action is supplied" {
        $protectedPlan = New-TestPlanEntry `
            -Name "Microsoft Defender Antivirus" `
            -Category "Security"

        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry $protectedPlan `
            -Environment $ReadyEnvironment

        $result.Status | Should -Be "Blocked"
        $result.SafetyPolicyResult | Should -Be "Blocked - Protected"
        $result.Reasons | Should -Match "protected or core-component"
    }

    It "blocks protected Microsoft scheduled tasks from final eligibility" {
        $protectedPlans = @(
            New-TestPlanEntry `
                -Name "SustainabilityTelemetry" `
                -Vendor "Microsoft" `
                -Category "General" `
                -Source "\Microsoft\Windows\Sustainability\"
            New-TestPlanEntry `
                -Name "Microsoft Compatibility Appraiser Exp" `
                -Vendor "Microsoft" `
                -Category "General" `
                -Source "\Microsoft\Windows\Application Experience\"
        )

        $results = @(
            New-ToolkitOptimizationPreflight `
                -PlanEntries $protectedPlans `
                -Environment $ReadyEnvironment
        )

        $results.Count | Should -Be 2
        foreach ($result in $results) {
            $result.Status | Should -Be "Blocked"
            $result.EligibilityStatus | Should -Be "Blocked"
            $result.IsEligible | Should -BeFalse
            $result.IsBlocked | Should -BeTrue
            $result.SafetyPolicyResult | Should -Be "Blocked - Protected"
            $result.Reasons | Should -Match "protected or core-component"
        }
    }

    It "blocks candidate actions outside the dedicated executor scope" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (
                New-TestPlanEntry `
                    -Source "\Vendor\"
            ) `
            -Environment $ReadyEnvironment

        $result.IsEligible | Should -BeFalse
        $result.SafetyPolicyResult | Should -Be "Blocked - Executor Scope"
        $result.Reasons | Should -Match "outside the dedicated HP task namespace"
    }

    It "blocks candidate actions not allowlisted for the executor" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (
                New-TestPlanEntry `
                    -Vendor "Contoso"
            ) `
            -Environment $ReadyEnvironment

        $result.IsEligible | Should -BeFalse
        $result.SafetyPolicyResult | Should -Be "Blocked - Executor Policy"
        $result.Reasons | Should -Match "No executor policy allowlists"
    }

    It "marks only the exact HP Insights Analytics service confirmation-required" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (New-TestServicePlanEntry) `
            -Environment $ReadyEnvironment

        $result.IsEligible | Should -BeTrue
        $result.Status | Should -Be "Confirmation Required"
        $result.SafetyPolicyResult | Should -Be "Allowed"
        $result.ReversibilityStatus | Should -Be "Reversible"
    }

    It "captures and hashes the complete HP service before-state" {
        $plan = New-TestServicePlanEntry
        $preflight = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry $plan `
            -Environment $ReadyEnvironment
        $manifest = ConvertTo-ToolkitRollbackManifestEntry `
            -PlanEntry $plan `
            -PreflightResult $preflight
        $snapshot = $manifest.BeforeStateSnapshot | ConvertFrom-Json

        $manifest.TargetIdentity | Should -Be "HpTouchpointAnalyticsService"
        $manifest.OperationType | Should -Be "ServiceStateChange"
        $manifest.BeforeStateCaptured | Should -BeTrue
        $manifest.IsReversible | Should -BeTrue
        $snapshot.ServiceName | Should -Be "HpTouchpointAnalyticsService"
        $snapshot.ServiceDisplayName | Should -Be "HP Insights Analytics"
        $snapshot.StartupType | Should -Be "Automatic"
        $snapshot.CurrentState | Should -Be "Running"
        $snapshot.Dependencies | Should -Be '["ProfSvc","rpcss"]'
        $snapshot.DependentServices | Should -Be '[]'
        $snapshot.ServiceStartName | Should -Be "LocalSystem"
        $snapshot.ServiceType | Should -Be "Own Process"
        $snapshot.ServicePath | Should -Be $snapshot.ExecutablePath
        $snapshot.ExecutableCompany | Should -Be "HP Inc."
        $snapshot.ExecutableProduct | Should -Be "HP Insights Analytics"
        $snapshot.ExecutableSignatureStatus | Should -Be "Valid"
        $snapshot.ExecutableSignerSubject |
            Should -Match "Microsoft Windows Hardware Compatibility Publisher"
        $snapshot.DelayedAutoStartConfiguration |
            Should -Match '"Present":false'
        $snapshot.RecoveryConfiguration |
            Should -Match "FailureActionsBase64"
        $manifest.BeforeStateHash |
            Should -Be (Get-ToolkitStableId -Prefix "BS" -Parts @($manifest.BeforeStateSnapshot))
    }

    It "canonicalizes equivalent delayed-start off representations" {
        $canonical = '{"Present":false,"Value":"0"}'
        foreach ($representation in @(
            $null,
            0,
            $false,
            "0",
            "false",
            "null",
            '{"Present":false,"Value":"0"}',
            '{"Present":true,"Value":"0"}',
            '{"Present":true,"Value":false}'
        )) {
            ConvertTo-ToolkitOptimizationDelayedAutoStartConfiguration `
                -Configuration $representation |
                Should -Be $canonical
        }
    }

    It "uses canonical delayed-start metadata in fresh plan and manifest hashes" {
        $absent = New-TestServicePlanEntry `
            -DelayedAutoStartConfiguration '{"Present":false,"Value":"0"}'
        $zero = New-TestServicePlanEntry `
            -DelayedAutoStartConfiguration '{"Present":true,"Value":"0"}'
        $absentPreflight = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry $absent `
            -Environment $ReadyEnvironment
        $zeroPreflight = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry $zero `
            -Environment $ReadyEnvironment
        $absentManifest = ConvertTo-ToolkitRollbackManifestEntry `
            -PlanEntry $absent `
            -PreflightResult $absentPreflight
        $zeroManifest = ConvertTo-ToolkitRollbackManifestEntry `
            -PlanEntry $zero `
            -PreflightResult $zeroPreflight

        $absent.DelayedAutoStartConfiguration |
            Should -Be '{"Present":false,"Value":"0"}'
        $zero.DelayedAutoStartConfiguration |
            Should -Be $absent.DelayedAutoStartConfiguration
        $zero.SourceFindingId | Should -Be $absent.SourceFindingId
        $zero.PlanId | Should -Be $absent.PlanId
        $zeroManifest.BeforeStateSnapshot |
            Should -Be $absentManifest.BeforeStateSnapshot
        $zeroManifest.BeforeStateHash |
            Should -Be $absentManifest.BeforeStateHash
        $zeroManifest.ManifestId | Should -Be $absentManifest.ManifestId
    }

    It "rejects meaningful delayed-start drift and malformed metadata" {
        foreach ($representation in @(
            '{"Present":true,"Value":"1"}',
            '{"Present":false,"Value":"1"}',
            '{"Present":false,"Value":"0","Ignored":false}',
            "2",
            "not-json"
        )) {
            Test-ToolkitOptimizationDelayedAutoStartConfiguration `
                -Json $representation |
                Should -BeFalse
        }
    }

    It "blocks service candidates with incomplete rollback metadata" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (
                New-TestServicePlanEntry -RecoveryConfiguration ""
            ) `
            -Environment $ReadyEnvironment

        $result.IsEligible | Should -BeFalse
        $result.SafetyPolicyResult | Should -Be "Blocked - Executor Scope"
        $result.Reasons | Should -Match "complete service safety metadata"
    }

    It "blocks service identities other than the exact allowlisted service" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (
                New-TestServicePlanEntry `
                    -ServiceName "HpOtherAnalyticsService"
            ) `
            -Environment $ReadyEnvironment

        $result.IsEligible | Should -BeFalse
        $result.SafetyPolicyResult | Should -Be "Blocked - Executor Policy"
    }

    It "blocks a lookalike service display name" {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (
                New-TestServicePlanEntry `
                    -DisplayName "HP Insights Analytics Helper"
            ) `
            -Environment $ReadyEnvironment

        $result.IsEligible | Should -BeFalse
        $result.SafetyPolicyResult | Should -Be "Blocked - Executor Policy"
    }

    It "blocks wildcard, alias, or path-like service identities" -ForEach @(
        @{ ServiceName = "HpTouchpoint*" }
        @{ ServiceName = "HpTouchpointAnalyticsService\..\EventLog" }
        @{ ServiceName = "EventLog" }
    ) {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (
                New-TestServicePlanEntry `
                    -ServiceName $ServiceName
            ) `
            -Environment $ReadyEnvironment

        $result.IsEligible | Should -BeFalse
        $result.SafetyPolicyResult |
            Should -Match "Blocked - Executor"
    }

    It "blocks missing, unexpected, or dependent service relationships" -ForEach @(
        @{ Dependencies = ""; DependentServices = '[]' }
        @{ Dependencies = '["rpcss"]'; DependentServices = '[]' }
        @{ Dependencies = '["ProfSvc","rpcss"]'; DependentServices = '["OtherService"]' }
        @{ Dependencies = '["ProfSvc","rpcss"]'; DependentServices = "not-json" }
    ) {
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (
                New-TestServicePlanEntry `
                    -Dependencies $Dependencies `
                    -DependentServices $DependentServices
            ) `
            -Environment $ReadyEnvironment

        $result.IsEligible | Should -BeFalse
        $result.SafetyPolicyResult |
            Should -Match "Blocked - Executor"
    }

    It "blocks missing or altered service provenance and recovery metadata" -ForEach @(
        @{ Parameter = "ServiceStartName"; Value = "LocalService" }
        @{ Parameter = "ServiceType"; Value = "Share Process" }
        @{ Parameter = "ExecutableCompany"; Value = "Contoso" }
        @{ Parameter = "ExecutableProduct"; Value = "HP Insights Analytics Helper" }
        @{ Parameter = "ExecutableSignatureStatus"; Value = "NotSigned" }
        @{ Parameter = "ExecutableSignerSubject"; Value = "CN=Contoso" }
        @{ Parameter = "ServicePath"; Value = "C:\Windows\System32\svchost.exe" }
        @{ Parameter = "DelayedAutoStartConfiguration"; Value = "" }
        @{ Parameter = "RecoveryConfiguration"; Value = '{"FailureActionsPresent":true,"FailureActionsBase64":"not-base64"}' }
        @{ Parameter = "RecoveryConfiguration"; Value = '{"FailureActionsPresent":true,"FailureActionsBase64":"AQIDBA==","FailureActionsOnNonCrashFailuresPresent":false,"FailureActionsOnNonCrashFailures":"","FailureCommandPresent":false,"FailureCommand":"","RebootMessagePresent":false,"RebootMessage":""}' }
        @{ Parameter = "RecoveryConfiguration"; Value = '{"FailureActionsPresent":true,"FailureActionsBase64":"gFEBAAEAAAABAAAAAwAAABQAAAABAAAAMHUAAAEAAABg6gAAAQAAAJBfAQA=","FailureActionsOnNonCrashFailuresPresent":false,"FailureActionsOnNonCrashFailures":"","FailureCommandPresent":true,"FailureCommand":"cmd.exe /c whoami","RebootMessagePresent":false,"RebootMessage":""}' }
    ) {
        $parameters = @{
            $Parameter = $Value
        }
        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (New-TestServicePlanEntry @parameters) `
            -Environment $ReadyEnvironment

        $result.IsEligible | Should -BeFalse
        $result.SafetyPolicyResult |
            Should -Match "Blocked - Executor"
    }

    It "reports unavailable restore-point readiness without creating one" {
        $environment = [PSCustomObject]@{
            IsWindowsPlatform       = $true
            IsAdministrator        = $true
            RestorePointCapability = "Unavailable"
            RestorePointReady      = $false
        }

        $result = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry (New-TestPlanEntry) `
            -Environment $environment

        $result.Status | Should -Be "Blocked"
        $result.RestorePointRequired | Should -BeTrue
        $result.RestorePointCapability | Should -Be "Unavailable"
        $result.RestorePointReady | Should -BeFalse
    }

    It "captures an immutable before-state snapshot for reversible actions" {
        $planEntry = New-TestPlanEntry
        $preflight = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry $planEntry `
            -Environment $ReadyEnvironment
        $first = ConvertTo-ToolkitRollbackManifestEntry `
            -PlanEntry $planEntry `
            -PreflightResult $preflight
        $second = ConvertTo-ToolkitRollbackManifestEntry `
            -PlanEntry $planEntry `
            -PreflightResult $preflight

        $first.BeforeStateCaptured | Should -BeTrue
        $first.IsReversible | Should -BeTrue
        $first.BeforeStateSnapshot | Should -Match '"CurrentState":"Ready"'
        $first.BeforeStateHash | Should -Be $second.BeforeStateHash
        $first.ManifestId | Should -Be $second.ManifestId
    }

    It "explicitly records actions that are not safely reversible" {
        $planEntry = New-TestPlanEntry `
            -Name "Contoso Application" `
            -Type "Software" `
            -State "Installed"
        $preflight = ConvertTo-ToolkitOptimizationPreflightResult `
            -PlanEntry $planEntry `
            -Environment $ReadyEnvironment
        $manifest = ConvertTo-ToolkitRollbackManifestEntry `
            -PlanEntry $planEntry `
            -PreflightResult $preflight

        $preflight.Status | Should -Be "Blocked"
        $preflight.ReversibilityStatus | Should -Be "Not Safely Reversible"
        $manifest.IsReversible | Should -BeFalse
        $manifest.ReversibilityStatement |
            Should -Match "not safely reversible"
    }

    It "exports preflight and rollback manifest JSON and CSV reports" {
        $plan = @(New-TestPlanEntry)
        $preflight = @(
            New-ToolkitOptimizationPreflight `
                -PlanEntries $plan `
                -Environment $ReadyEnvironment
        )
        $manifest = @(
            New-ToolkitRollbackManifest `
                -PlanEntries $plan `
                -PreflightResults $preflight
        )
        $preflightPaths = Save-ToolkitOptimizationPreflightReports `
            -PreflightResults $preflight
        $rollbackPaths = Save-ToolkitRollbackManifestReports `
            -RollbackManifest $manifest

        Test-Path $preflightPaths.CsvPath | Should -BeTrue
        Test-Path $preflightPaths.JsonPath | Should -BeTrue
        Test-Path $rollbackPaths.CsvPath | Should -BeTrue
        Test-Path $rollbackPaths.JsonPath | Should -BeTrue
        (Import-Csv $preflightPaths.CsvPath)[0].PreflightId |
            Should -Be $preflight[0].PreflightId
        (Get-Content $rollbackPaths.JsonPath -Raw | ConvertFrom-Json)[0].ManifestId |
            Should -Be $manifest[0].ManifestId
    }

    It "contains no system-changing command invocations in optimizer code" {
        $forbiddenCommands = @(
            "Set-Service", "Start-Service", "Stop-Service", "Restart-Service",
            "Set-ItemProperty", "New-ItemProperty", "Remove-ItemProperty",
            "Set-ScheduledTask", "Enable-ScheduledTask", "Disable-ScheduledTask",
            "Enable-WindowsOptionalFeature", "Disable-WindowsOptionalFeature",
            "Add-AppxPackage", "Remove-AppxPackage", "Uninstall-Package",
            "Checkpoint-Computer", "powercfg", "winget"
        )
        $invokedCommands = foreach ($path in @(
            "$Root\Core\Optimizer.psm1"
            "$Root\Modules\Optimizer.ps1"
        )) {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $path,
                [ref]$tokens,
                [ref]$errors
            )

            @($errors).Count | Should -Be 0
            $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst]
            }, $true) | ForEach-Object {
                $_.GetCommandName()
            }
        }

        foreach ($command in $forbiddenCommands) {
            $invokedCommands | Should -Not -Contain $command
        }
    }
}

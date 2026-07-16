Describe "Gated Safe Optimizer Executor" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot
        Import-Module "$Root\Core\Models.psm1" -Force
        Import-Module "$Root\Core\OptimizerExecutor.psm1" -Force
        Import-Module "$Root\Core\Optimizer.psm1" -Force
        Import-Module "$Root\Core\Reporting.psm1" -Force

        $ReadyEnvironment = [PSCustomObject]@{
            IsWindowsPlatform       = $true
            IsAdministrator        = $true
            RestorePointCapability = "Available"
            RestorePointReady      = $true
        }

        function New-TestExecutionArtifacts {
            param(
                [string]$Suffix = "one",
                [string]$Name = "HP Telemetry Task",
                [string]$Type = "ScheduledTask",
                [string]$Vendor = "HP",
                [string]$Source = "\HP\",
                [string]$State = "Ready",
                [string]$ActionId = "review-likely-disable",
                [string]$Category = "Telemetry",
                [string]$Recommendation = "Review / likely disable",
                [string]$ReportFile = "ScheduledTasks_Report.csv"
            )

            $sourceFindingId = Get-ToolkitStableId `
                -Prefix "TF" `
                -Parts @($Type, $Name, $Source, $Suffix, $ReportFile)
            $planId = Get-ToolkitStableId `
                -Prefix "OP" `
                -Parts @($sourceFindingId, $ActionId)
            $plan = New-ToolkitOptimizationPlanEntry `
                -PlanId $planId `
                -SourceFindingId $sourceFindingId `
                -SourceFinding "${Type}: $Name" `
                -SourceName $Name `
                -SourceType $Type `
                -SourceVersion $Suffix `
                -ProposedAction "Review as a potential future optimization" `
                -ActionId $ActionId `
                -CurrentState $State `
                -Risk "Low" `
                -Reason "Optional HP telemetry task." `
                -Confidence "High" `
                -Category $Category `
                -Vendor $Vendor `
                -Recommendation $Recommendation `
                -Source $Source `
                -ReportFile $ReportFile `
                -RequiresConfirmation $true `
                -ConfirmationRequirement "Explicit confirmation is required." `
                -PlanStatus "Pending Review"
            $preflight = ConvertTo-ToolkitOptimizationPreflightResult `
                -PlanEntry $plan `
                -Environment $ReadyEnvironment
            $manifest = ConvertTo-ToolkitRollbackManifestEntry `
                -PlanEntry $plan `
                -PreflightResult $preflight

            return [PSCustomObject]@{
                Plan      = $plan
                Preflight = $preflight
                Manifest  = $manifest
            }
        }

        function New-TestServiceExecutionArtifacts {
            param(
                [string]$ServiceName = "HpTouchpointAnalyticsService",
                [string]$DisplayName = "HP Insights Analytics",
                [string]$StartupType = "Automatic",
                [string]$State = "Running",
                [string]$Dependencies = '["ProfSvc","rpcss"]',
                [string]$RecoveryConfiguration = '{"FailureActionsPresent":true,"FailureActionsBase64":"AQIDBA==","FailureActionsOnNonCrashFailures":"1"}'
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
                -Dependencies $Dependencies `
                -RecoveryConfiguration $RecoveryConfiguration
            $finding |
                Add-Member `
                    -NotePropertyName ReportFile `
                    -NotePropertyValue "Service_Analyzer.csv"
            $plan = ConvertTo-ToolkitOptimizationPlanEntry -Finding $finding
            $preflight = ConvertTo-ToolkitOptimizationPreflightResult `
                -PlanEntry $plan `
                -Environment $ReadyEnvironment
            $manifest = ConvertTo-ToolkitRollbackManifestEntry `
                -PlanEntry $plan `
                -PreflightResult $preflight

            return [PSCustomObject]@{
                Plan      = $plan
                Preflight = $preflight
                Manifest  = $manifest
            }
        }
    }

    BeforeEach {
        $Global:ToolkitRunPath = Join-Path $TestDrive "ExecutorReports"
        $Global:ToolkitExecutorMockStates = [System.Collections.Generic.Queue[string]]::new()
        $Global:ToolkitExecutorMockStates.Enqueue("Ready")
        $Global:ToolkitExecutorServiceStates = [System.Collections.Generic.Queue[object]]::new()
        $Global:ToolkitExecutorServiceStates.Enqueue(
            [PSCustomObject]@{
                State       = "Running"
                StartupType = "Automatic"
            }
        )
        Mock Get-ScheduledTask -ModuleName OptimizerExecutor {
            $state = if ($Global:ToolkitExecutorMockStates.Count -gt 0) {
                $Global:ToolkitExecutorMockStates.Dequeue()
            }
            else {
                "Ready"
            }

            [PSCustomObject]@{
                TaskName = $TaskName
                TaskPath = $TaskPath
                State    = $state
                Author   = "HP Inc."
            }
        }
        Mock Get-ToolkitPreflightEnvironment -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                IsWindowsPlatform       = $true
                IsAdministrator        = $true
                RestorePointCapability = "Available"
                RestorePointReady      = $true
            }
        }
        Mock Disable-ScheduledTask -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                TaskName = $TaskName
                TaskPath = $TaskPath
            }
        }
        Mock Get-ToolkitServiceInventoryRecord -ModuleName OptimizerExecutor {
            $state = if ($Global:ToolkitExecutorServiceStates.Count -gt 0) {
                $Global:ToolkitExecutorServiceStates.Dequeue()
            }
            else {
                [PSCustomObject]@{
                    State       = "Running"
                    StartupType = "Automatic"
                }
            }

            [PSCustomObject]@{
                Name                  = "HpTouchpointAnalyticsService"
                DisplayName           = "HP Insights Analytics"
                State                 = $state.State
                StartupType           = $state.StartupType
                Dependencies          = if ($state.Dependencies) {
                    $state.Dependencies
                }
                else {
                    '["ProfSvc","rpcss"]'
                }
                RecoveryConfiguration = if ($state.RecoveryConfiguration) {
                    $state.RecoveryConfiguration
                }
                else {
                    '{"FailureActionsPresent":true,"FailureActionsBase64":"AQIDBA==","FailureActionsOnNonCrashFailures":"1"}'
                }
            }
        }
        Mock Stop-Service -ModuleName OptimizerExecutor {}
        Mock Set-Service -ModuleName OptimizerExecutor {}
    }

    It "defines a narrow JSON execution allowlist" {
        $rules = Get-ToolkitOptimizationActionRules

        $rules.executionPolicies.Count | Should -Be 2
        $policy = $rules.executionPolicies |
            Where-Object id -eq "disable-hp-scheduled-task"
        $policy.actionId | Should -Be "review-likely-disable"
        $policy.operationType | Should -Be "ScheduledTaskStateChange"
        $policy.allowedVendors | Should -Contain "HP"
        $policy.allowedReportFiles | Should -Contain "ScheduledTasks_Report.csv"
        $policy.allowedCurrentStates | Should -Contain "Ready"
        $policy.allowedTaskPathPrefixes | Should -Contain "\HP\"
        $policy.allowedTaskNamePatterns | Should -Contain "HP Insights"
        $policy.allowedTaskAuthorPatterns | Should -Contain "HP"
        $policy.mutatingCommands | Should -Contain "Disable-ScheduledTask"

        $servicePolicy = $rules.executionPolicies |
            Where-Object id -eq "disable-hp-insights-analytics-service"
        $servicePolicy.serviceName |
            Should -Be "HpTouchpointAnalyticsService"
        $servicePolicy.serviceDisplayName |
            Should -Be "HP Insights Analytics"
        $servicePolicy.sourceTypes | Should -Be @("Service")
        $servicePolicy.allowedVendors | Should -Be @("HP")
        $servicePolicy.allowedReportFiles |
            Should -Be @("Service_Analyzer.csv")
        $servicePolicy.mutatingCommands | Should -Contain "Stop-Service"
        $servicePolicy.mutatingCommands | Should -Contain "Set-Service"
    }

    It "exposes plan review and dry-run in the menu without default Apply" {
        $menuText = Get-Content -Path "$Root\Start.ps1" -Raw
        $moduleText = Get-Content `
            -Path "$Root\Modules\OptimizerExecutor.ps1" `
            -Raw

        $menuText | Should -Match "Safe Optimizer Plan and Preflight"
        $menuText | Should -Match "Safe Optimizer Dry-Run"
        $menuText | Should -Match "Modules\\OptimizerExecutor\.ps1"
        $moduleText | Should -Match "\[switch\]\`$Apply"
        $moduleText | Should -Match "Dry-run is the default"
    }

    It "exposes native WhatIf and Confirm semantics" {
        $command = Get-Command Invoke-ToolkitOptimizationExecutor

        $command.Parameters.Keys | Should -Contain "WhatIf"
        $command.Parameters.Keys | Should -Contain "Confirm"
        $command.Parameters.Keys | Should -Contain "Apply"
        $command.Parameters.Keys | Should -Contain "Confirmed"
        $command.Parameters.Keys | Should -Not -Contain "Rules"
        $command.Parameters.Keys | Should -Not -Contain "Environment"
        Get-Command Invoke-ToolkitAllowedExecutionOperation `
            -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It "defaults to dry-run preview and invokes no mutation" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest)

        $result.Status | Should -Be "Preview"
        $result.AttemptMode | Should -Be "DryRun"
        $result.Applied | Should -BeFalse
        $result.DecisionCode | Should -Be "ApplyRequired"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "defaults the exact HP service capability to dry-run with no mutation" {
        $artifacts = New-TestServiceExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest)

        $result.Status | Should -Be "Preview"
        $result.DecisionCode | Should -Be "ApplyRequired"
        $result.Applied | Should -BeFalse
        Should -Invoke Stop-Service -ModuleName OptimizerExecutor -Times 0
        Should -Invoke Set-Service -ModuleName OptimizerExecutor -Times 0
    }

    It "honors WhatIf and invokes no mutation" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -WhatIf `
            -Confirm:$false

        $result.Status | Should -Be "WhatIf"
        $result.DecisionCode | Should -Be "WhatIfPreview"
        $result.Applied | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "records missing Apply as a preview requirement" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Confirmed

        $result.Status | Should -Be "Preview"
        $result.Reason | Should -Match "Apply was not specified"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies Apply when explicit confirmation is missing" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirm:$false

        $result.Status | Should -Be "Denied"
        $result.DecisionCode | Should -Be "ConfirmationMissing"
        $result.ConfirmationProvided | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies failed preflight results" {
        $artifacts = New-TestExecutionArtifacts
        $failedPreflight = $artifacts.Preflight | Select-Object *
        $failedPreflight.IsEligible = $false
        $failedPreflight.IsBlocked = $true
        $failedPreflight.EligibilityStatus = "Blocked"
        $failedPreflight.Status = "Blocked"

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($failedPreflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "InvalidOrStalePreflight"
        $result.PreflightValid | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies stale current state" {
        $artifacts = New-TestExecutionArtifacts
        Mock Get-ScheduledTask -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                TaskName = $TaskName
                TaskPath = $TaskPath
                State    = "Disabled"
                Author   = "HP Inc."
            }
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "StaleCurrentState"
        $result.CurrentStateValid | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies objects already in the target state" {
        $artifacts = New-TestExecutionArtifacts -State "Disabled"
        Mock Get-ScheduledTask -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                TaskName = $TaskName
                TaskPath = $TaskPath
                State    = "Disabled"
                Author   = "HP Inc."
            }
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "AlreadyAtTargetState"
        $result.Applied | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies actions without a rollback manifest" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @() `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "MissingRollbackManifest"
        $result.ManifestValid | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies manifests without a complete before-state snapshot" {
        $artifacts = New-TestExecutionArtifacts
        $invalidManifest = $artifacts.Manifest | Select-Object *
        $invalidManifest.BeforeStateCaptured = $false

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($invalidManifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "InvalidRollbackManifest"
        $result.ManifestValid | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies altered plan fields whose stable identity was not regenerated" {
        $artifacts = New-TestExecutionArtifacts
        $alteredPlan = $artifacts.Plan | Select-Object *
        $alteredPlan.SourceName = "HP Telemetry Altered"
        $alteredPlan.SourceFinding = "ScheduledTask: HP Telemetry Altered"

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($alteredPlan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "InvalidPlanIdentity"
        Should -Invoke Get-ScheduledTask -ModuleName OptimizerExecutor -Times 0
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies ambiguous duplicate preflight or rollback records" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight, $artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest, $artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "AmbiguousExecutionArtifacts"
        $result.MutationAttempted | Should -BeFalse
        Should -Invoke Get-ScheduledTask -ModuleName OptimizerExecutor -Times 0
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "permanently denies protected components" {
        $artifacts = New-TestExecutionArtifacts
        $protectedPlan = $artifacts.Plan | Select-Object *
        $protectedPlan.SourceName = "Microsoft Defender Maintenance"
        $protectedPlan.SourceFinding = "ScheduledTask: Microsoft Defender Maintenance"

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($protectedPlan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "ProtectedComponent"
        $result.PolicyAllowed | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies unsupported action types" {
        $artifacts = New-TestExecutionArtifacts `
            -Type "Startup Command" `
            -Source "HKCU:\Software\Contoso\Run"

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "ExecutionPolicyDenied"
        $result.PolicyAllowed | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "executes an eligible allowlisted action only through a mocked command" {
        $artifacts = New-TestExecutionArtifacts
        $Global:ToolkitExecutorMockStates.Clear()
        @("Ready", "Ready", "Disabled") | ForEach-Object {
            $Global:ToolkitExecutorMockStates.Enqueue($_)
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.Status | Should -Be "Executed"
        $result.Applied | Should -BeTrue
        $result.MutationAttempted | Should -BeTrue
        $result.ObservedStateAfter | Should -Be "Disabled"
        $result.RollbackStatus | Should -Be "Available"
        $result.ShouldProcessApproved | Should -BeTrue
        Should -Invoke Disable-ScheduledTask `
            -ModuleName OptimizerExecutor `
            -Times 1 `
            -ParameterFilter {
                $TaskName -eq "HP Telemetry Task" -and
                $TaskPath -eq "\HP\"
            }
    }

    It "executes only the exact allowlisted HP service through mocked commands" {
        $artifacts = New-TestServiceExecutionArtifacts
        $Global:ToolkitExecutorServiceStates.Clear()
        @(
            [PSCustomObject]@{ State = "Running"; StartupType = "Automatic" }
            [PSCustomObject]@{ State = "Running"; StartupType = "Automatic" }
            [PSCustomObject]@{ State = "Stopped"; StartupType = "Disabled" }
        ) | ForEach-Object {
            $Global:ToolkitExecutorServiceStates.Enqueue($_)
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.Status | Should -Be "Executed"
        $result.DecisionCode | Should -Be "Executed"
        $result.ObservedStateAfter |
            Should -Be "State=Stopped;StartupType=Disabled"
        $result.RollbackStatus | Should -Be "Available"
        Should -Invoke Stop-Service `
            -ModuleName OptimizerExecutor `
            -Times 1 `
            -ParameterFilter {
                $Name -eq "HpTouchpointAnalyticsService"
            }
        Should -Invoke Set-Service `
            -ModuleName OptimizerExecutor `
            -Times 1 `
            -ParameterFilter {
                $Name -eq "HpTouchpointAnalyticsService" -and
                $StartupType -eq "Disabled"
            }
        Should -Invoke Disable-ScheduledTask `
            -ModuleName OptimizerExecutor `
            -Times 0
    }

    It "denies live HP service dependency or recovery drift" {
        $artifacts = New-TestServiceExecutionArtifacts
        $Global:ToolkitExecutorServiceStates.Clear()
        $Global:ToolkitExecutorServiceStates.Enqueue(
            [PSCustomObject]@{
                State                 = "Running"
                StartupType           = "Automatic"
                Dependencies          = '["DifferentDependency"]'
                RecoveryConfiguration = '{"FailureActionsPresent":false,"FailureActionsBase64":"","FailureActionsOnNonCrashFailures":""}'
            }
        )

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "StaleCurrentState"
        $result.CurrentStateValid | Should -BeFalse
        Should -Invoke Stop-Service -ModuleName OptimizerExecutor -Times 0
        Should -Invoke Set-Service -ModuleName OptimizerExecutor -Times 0
    }

    It "denies any service identity other than the exact allowlisted name" {
        $artifacts = New-TestServiceExecutionArtifacts `
            -ServiceName "HpOtherAnalyticsService"

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "ExecutionPolicyDenied"
        Should -Invoke Stop-Service -ModuleName OptimizerExecutor -Times 0
        Should -Invoke Set-Service -ModuleName OptimizerExecutor -Times 0
    }

    It "records partial HP service failure as rollback-required" {
        $artifacts = New-TestServiceExecutionArtifacts
        $Global:ToolkitExecutorServiceStates.Clear()
        @(
            [PSCustomObject]@{ State = "Running"; StartupType = "Automatic" }
            [PSCustomObject]@{ State = "Running"; StartupType = "Automatic" }
            [PSCustomObject]@{ State = "Stopped"; StartupType = "Automatic" }
        ) | ForEach-Object {
            $Global:ToolkitExecutorServiceStates.Enqueue($_)
        }
        Mock Set-Service -ModuleName OptimizerExecutor {
            throw "Mock startup-type failure"
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.Status | Should -Be "Indeterminate"
        $result.DecisionCode |
            Should -Be "ExecutionOutcomeIndeterminate"
        $result.MutationAttempted | Should -BeTrue
        $result.RollbackRequired | Should -BeTrue
        $result.RollbackStatus |
            Should -Be "Required - Not Executed"
        Should -Invoke Stop-Service -ModuleName OptimizerExecutor -Times 1
        Should -Invoke Set-Service -ModuleName OptimizerExecutor -Times 1
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies a coherently regenerated plan outside the dedicated HP task path" {
        $artifacts = New-TestExecutionArtifacts `
            -Name "HP Telemetry Core Task" `
            -Source "\Microsoft\Windows\DiskCleanup\"

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "ProtectedComponent"
        $result.MutationAttempted | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies wildcard and non-literal task identities" {
        $artifacts = New-TestExecutionArtifacts -Name "HP Telemetry *"

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "UnsafeTargetIdentity"
        Should -Invoke Get-ScheduledTask -ModuleName OptimizerExecutor -Times 0
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies tasks that do not match the HP telemetry action scope" {
        $artifacts = New-TestExecutionArtifacts -Name "HP Printer Update"

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "TargetScopeMismatch"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies a live task with a mismatched identity" {
        $artifacts = New-TestExecutionArtifacts
        Mock Get-ScheduledTask -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                TaskName = "Different Task"
                TaskPath = $TaskPath
                State    = "Ready"
                Author   = "Microsoft Corporation"
            }
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "StaleCurrentState"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies a lookalike task author that only contains the HP token" {
        $artifacts = New-TestExecutionArtifacts
        Mock Get-ScheduledTask -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                TaskName = $TaskName
                TaskPath = $TaskPath
                State    = "Ready"
                Author   = "NotHP Software"
            }
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "StaleCurrentState"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies modified policy metadata that attempts to widen or inject execution" {
        $artifacts = New-TestExecutionArtifacts -Name "HP Printer Update"
        $tamperedRules = Get-ToolkitOptimizationActionRules |
            ConvertTo-Json -Depth 20 |
            ConvertFrom-Json
        $tamperedRules.executionPolicies[0].allowedTaskNamePatterns = @("*")
        $tamperedRules.executionPolicies[0].allowedTaskPathPrefixes = @("\")
        $tamperedRules.executionPolicies[0].mutatingCommands = @("Invoke-Expression")
        Mock Get-ToolkitOptimizationActionRules -ModuleName OptimizerExecutor {
            $tamperedRules
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "ExecutionPolicyDenied"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies execution when the live administrator check is not ready" {
        $artifacts = New-TestExecutionArtifacts
        Mock Get-ToolkitPreflightEnvironment -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                IsWindowsPlatform       = $true
                IsAdministrator        = $false
                RestorePointCapability = "Available"
                RestorePointReady      = $false
            }
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "AdministratorRequired"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "denies execution when restore-point readiness is unavailable" {
        $artifacts = New-TestExecutionArtifacts
        Mock Get-ToolkitPreflightEnvironment -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                IsWindowsPlatform       = $true
                IsAdministrator        = $true
                RestorePointCapability = "Unavailable"
                RestorePointReady      = $false
            }
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "RestorePointNotReady"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "revalidates live state after confirmation and denies drift" {
        $artifacts = New-TestExecutionArtifacts
        $Global:ToolkitExecutorMockStates.Clear()
        @("Ready", "Disabled") | ForEach-Object {
            $Global:ToolkitExecutorMockStates.Enqueue($_)
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "FinalValidationFailed"
        $result.Reason | Should -Match "StaleCurrentState"
        $result.MutationAttempted | Should -BeFalse
        Should -Invoke Get-ScheduledTask -ModuleName OptimizerExecutor -Times 2
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "does not report execution success when post-state verification fails" {
        $artifacts = New-TestExecutionArtifacts
        $Global:ToolkitExecutorMockStates.Clear()
        @("Ready", "Ready", "Ready") | ForEach-Object {
            $Global:ToolkitExecutorMockStates.Enqueue($_)
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.Status | Should -Be "Failed"
        $result.DecisionCode | Should -Be "PostStateMismatch"
        $result.Applied | Should -BeFalse
        $result.MutationAttempted | Should -BeTrue
        $result.RollbackRequired | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 1
    }

    It "records a failed operation that changed state as rollback-required" {
        $artifacts = New-TestExecutionArtifacts
        $Global:ToolkitExecutorMockStates.Clear()
        @("Ready", "Ready", "Disabled") | ForEach-Object {
            $Global:ToolkitExecutorMockStates.Enqueue($_)
        }
        Mock Disable-ScheduledTask -ModuleName OptimizerExecutor {
            throw "Provider response was interrupted."
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.Status | Should -Be "FailedAfterStateChange"
        $result.DecisionCode | Should -Be "ExecutionFailedAfterStateChange"
        $result.Applied | Should -BeTrue
        $result.MutationAttempted | Should -BeTrue
        $result.ObservedStateAfter | Should -Be "Disabled"
        $result.RollbackRequired | Should -BeTrue
        $result.RollbackStatus | Should -Be "Required - Not Executed"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 1
    }

    It "produces one standardized audit record for every attempted action" {
        $first = New-TestExecutionArtifacts -Suffix "one"
        $second = New-TestExecutionArtifacts `
            -Suffix "two" `
            -Name "HP Analytics Task"

        $results = @(
            Invoke-ToolkitOptimizationExecutor `
                -PlanEntries @($first.Plan, $second.Plan) `
                -PreflightResults @($first.Preflight, $second.Preflight) `
                -RollbackManifest @($first.Manifest, $second.Manifest)
        )

        $results.Count | Should -Be 2
        @(
            "ExecutionId", "PlanId", "PreflightId", "ManifestId", "ActionId",
            "AttemptMode", "Status", "DecisionCode", "Applied",
            "MutationAttempted", "ObservedStateAfter", "RollbackRequired",
            "RollbackStatus", "Reason", "Remediation", "AttemptedAtUtc"
        ) | ForEach-Object {
            $results[0].PSObject.Properties.Name | Should -Contain $_
        }
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "preserves rollback metadata in the execution audit" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest)

        $result.BeforeStateHash | Should -Be $artifacts.Manifest.BeforeStateHash
        $result.RollbackOperationType | Should -Be "EnableScheduledTask"
        $result.RollbackTargetState | Should -Be "Enabled"
    }

    It "exports execution audit records to CSV and JSON" {
        $artifacts = New-TestExecutionArtifacts
        $results = @(
            Invoke-ToolkitOptimizationExecutor `
                -PlanEntries @($artifacts.Plan) `
                -PreflightResults @($artifacts.Preflight) `
                -RollbackManifest @($artifacts.Manifest)
        )

        $paths = Save-ToolkitOptimizationExecutionReports `
            -ExecutionResults $results

        Test-Path $paths.CsvPath | Should -BeTrue
        Test-Path $paths.JsonPath | Should -BeTrue
        (Import-Csv $paths.CsvPath)[0].ExecutionId |
            Should -Be $results[0].ExecutionId
        (Get-Content $paths.JsonPath -Raw | ConvertFrom-Json)[0].DecisionCode |
            Should -Be "ApplyRequired"
    }

    It "neutralizes formula-leading execution CSV values without altering JSON" {
        $artifacts = New-TestExecutionArtifacts -Name "=HYPERLINK harmless"
        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest)

        $paths = Save-ToolkitOptimizationExecutionReports `
            -ExecutionResults @($result)
        $csvResult = Import-Csv $paths.CsvPath
        $jsonResult = Get-Content $paths.JsonPath -Raw | ConvertFrom-Json

        $csvResult.SourceName | Should -Be "'=HYPERLINK harmless"
        $jsonResult[0].SourceName | Should -Be "=HYPERLINK harmless"
    }

    It "mocks every JSON-policy mutating command used by executor tests" {
        $rules = Get-ToolkitOptimizationActionRules
        $testText = Get-Content -Path $PSCommandPath -Raw

        foreach ($command in @($rules.executionPolicies.mutatingCommands)) {
            $testText | Should -Match (
                "Mock\s+" +
                [regex]::Escape([string]$command)
            )
        }
    }
}

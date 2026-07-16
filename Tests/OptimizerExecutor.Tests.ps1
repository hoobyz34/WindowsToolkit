Describe "Gated Safe Optimizer Executor" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot
        Import-Module "$Root\Core\Models.psm1" -Force
        Import-Module "$Root\Core\Optimizer.psm1" -Force
        Import-Module "$Root\Core\OptimizerExecutor.psm1" -Force
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
                [string]$ActionId = "review-likely-disable"
            )

            $plan = New-ToolkitOptimizationPlanEntry `
                -PlanId "OP-$Suffix" `
                -SourceFindingId "TF-$Suffix" `
                -SourceFinding "${Type}: $Name" `
                -SourceName $Name `
                -SourceType $Type `
                -SourceVersion "" `
                -ProposedAction "Review as a potential future optimization" `
                -ActionId $ActionId `
                -CurrentState $State `
                -Risk "Low" `
                -Reason "Optional HP telemetry task." `
                -Confidence "High" `
                -Category "Telemetry" `
                -Vendor $Vendor `
                -Recommendation "Review / likely disable" `
                -Source $Source `
                -ReportFile "ScheduledTasks_Report.csv" `
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
    }

    BeforeEach {
        $Global:ToolkitRunPath = Join-Path $TestDrive "ExecutorReports"
        Mock Get-ScheduledTask -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                State = "Ready"
            }
        }
        Mock Disable-ScheduledTask -ModuleName OptimizerExecutor {
            [PSCustomObject]@{
                TaskName = $TaskName
                TaskPath = $TaskPath
            }
        }
    }

    It "defines a narrow JSON execution allowlist" {
        $rules = Get-ToolkitOptimizationActionRules

        $rules.executionPolicies.Count | Should -Be 1
        $policy = $rules.executionPolicies[0]
        $policy.actionId | Should -Be "review-likely-disable"
        $policy.operationType | Should -Be "ScheduledTaskStateChange"
        $policy.allowedVendors | Should -Contain "HP"
        $policy.allowedReportFiles | Should -Contain "ScheduledTasks_Report.csv"
        $policy.allowedCurrentStates | Should -Contain "Ready"
        $policy.mutatingCommand | Should -Be "Disable-ScheduledTask"
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
    }

    It "defaults to dry-run preview and invokes no mutation" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Environment $ReadyEnvironment

        $result.Status | Should -Be "Preview"
        $result.AttemptMode | Should -Be "DryRun"
        $result.Applied | Should -BeFalse
        $result.DecisionCode | Should -Be "ApplyRequired"
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "honors WhatIf and invokes no mutation" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Environment $ReadyEnvironment `
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
            -Environment $ReadyEnvironment `
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
            -Environment $ReadyEnvironment `
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
            -Environment $ReadyEnvironment `
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
                State = "Disabled"
            }
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Environment $ReadyEnvironment `
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
                State = "Disabled"
            }
        }

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Environment $ReadyEnvironment `
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
            -Environment $ReadyEnvironment `
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
            -Environment $ReadyEnvironment `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "InvalidRollbackManifest"
        $result.ManifestValid | Should -BeFalse
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
            -Environment $ReadyEnvironment `
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
            -Environment $ReadyEnvironment `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.DecisionCode | Should -Be "ExecutionPolicyDenied"
        $result.PolicyAllowed | Should -BeFalse
        Should -Invoke Disable-ScheduledTask -ModuleName OptimizerExecutor -Times 0
    }

    It "executes an eligible allowlisted action only through a mocked command" {
        $artifacts = New-TestExecutionArtifacts

        $result = Invoke-ToolkitOptimizationExecutor `
            -PlanEntries @($artifacts.Plan) `
            -PreflightResults @($artifacts.Preflight) `
            -RollbackManifest @($artifacts.Manifest) `
            -Environment $ReadyEnvironment `
            -Apply `
            -Confirmed `
            -Confirm:$false

        $result.Status | Should -Be "Executed"
        $result.Applied | Should -BeTrue
        $result.ShouldProcessApproved | Should -BeTrue
        Should -Invoke Disable-ScheduledTask `
            -ModuleName OptimizerExecutor `
            -Times 1 `
            -ParameterFilter {
                $TaskName -eq "HP Telemetry Task" -and
                $TaskPath -eq "\HP\"
            }
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
                -RollbackManifest @($first.Manifest, $second.Manifest) `
                -Environment $ReadyEnvironment
        )

        $results.Count | Should -Be 2
        @(
            "ExecutionId", "PlanId", "PreflightId", "ManifestId", "ActionId",
            "AttemptMode", "Status", "DecisionCode", "Applied", "Reason",
            "Remediation", "AttemptedAtUtc"
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
            -RollbackManifest @($artifacts.Manifest) `
            -Environment $ReadyEnvironment

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
                -RollbackManifest @($artifacts.Manifest) `
                -Environment $ReadyEnvironment
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

    It "mocks every JSON-policy mutating command used by executor tests" {
        $rules = Get-ToolkitOptimizationActionRules
        $testText = Get-Content -Path $PSCommandPath -Raw

        foreach ($command in @($rules.executionPolicies.mutatingCommand)) {
            $testText | Should -Match (
                "Mock\s+" +
                [regex]::Escape([string]$command)
            )
        }
    }
}

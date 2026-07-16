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
                [string]$Name = "Contoso Startup Helper",
                [string]$Type = "Startup Command",
                [AllowEmptyString()][string]$State = "Enabled",
                [string]$ActionId = "review-likely-disable",
                [string]$Category = "Optional",
                [string]$Risk = "Low",
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
                -Vendor "Contoso" `
                -Recommendation "Review / likely disable" `
                -Source "Pester" `
                -ReportFile "Test_Report.csv" `
                -RequiresConfirmation $RequiresConfirmation `
                -ConfirmationRequirement "Explicit confirmation is required." `
                -PlanStatus "Pending Review"
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
        $first.BeforeStateSnapshot | Should -Match '"CurrentState":"Enabled"'
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

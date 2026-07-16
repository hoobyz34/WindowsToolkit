Describe "Safe Optimizer Planning" {

    BeforeAll {
        $Root = Split-Path -Parent $PSScriptRoot
        Import-Module "$Root\Core\Models.psm1" -Force
        Import-Module "$Root\Core\Reporting.psm1" -Force
        Import-Module "$Root\Core\Optimizer.psm1" -Force

        $ReviewFinding = New-ToolkitFinding `
            -Name "HP Analytics" `
            -Type "Software" `
            -Vendor "HP" `
            -Category "Telemetry" `
            -Recommendation "Review / likely disable" `
            -Risk "Low" `
            -Reason "Optional telemetry component." `
            -Source "Installed software" `
            -Version "1.0" `
            -State "Installed"
    }

    BeforeEach {
        $Global:ToolkitRunPath = Join-Path $TestDrive "OptimizerReports"
    }

    It "loads valid JSON action knowledge" {
        $rules = Get-ToolkitOptimizationActionRules

        $rules.actions.Count | Should -BeGreaterThan 0
        $rules.protectedAction.id | Should -Not -BeNullOrEmpty
        $rules.defaultAction.confirmationRequirement | Should -Not -BeNullOrEmpty

        foreach ($action in $rules.actions) {
            $action.id | Should -Not -BeNullOrEmpty
            $action.recommendation | Should -Not -BeNullOrEmpty
            $action.proposedAction | Should -Not -BeNullOrEmpty
            $action.confirmationRequirement | Should -Not -BeNullOrEmpty
        }
    }

    It "creates a complete standardized plan entry" {
        $entry = ConvertTo-ToolkitOptimizationPlanEntry -Finding $ReviewFinding

        @(
            "PlanId", "SourceFindingId", "SourceFinding", "ProposedAction",
            "CurrentState", "Risk", "Reason", "Confidence", "Category",
            "RequiresConfirmation", "ConfirmationRequirement"
        ) | ForEach-Object {
            $entry.PSObject.Properties.Name | Should -Contain $_
        }

        $entry.SourceFinding | Should -Be "Software: HP Analytics"
        $entry.ProposedAction | Should -Be "Review as a potential future optimization"
        $entry.RequiresConfirmation | Should -BeTrue
        $entry.ConfirmationRequirement | Should -Not -BeNullOrEmpty
    }

    It "uses stable identities and deterministic ordering" {
        $secondFinding = New-ToolkitFinding `
            -Name "Contoso Helper" `
            -Type "Startup" `
            -Vendor "Contoso" `
            -Category "Optional" `
            -Recommendation "Review" `
            -Risk "Low" `
            -Reason "Optional startup item." `
            -Source "Startup" `
            -Version "" `
            -State "Enabled"

        $firstPlan = @(New-ToolkitOptimizationPlan -Findings @($ReviewFinding, $secondFinding))
        $secondPlan = @(New-ToolkitOptimizationPlan -Findings @($secondFinding, $ReviewFinding))

        $firstPlan.PlanId | Should -Be $secondPlan.PlanId
        $firstPlan.SourceFindingId | Should -Be ($firstPlan.SourceFindingId | Sort-Object)
        (ConvertTo-ToolkitOptimizationPlanEntry -Finding $ReviewFinding).PlanId |
            Should -Be (ConvertTo-ToolkitOptimizationPlanEntry -Finding $ReviewFinding).PlanId
    }

    It "retains protected findings even when their recommendation requests review" {
        $protectedFinding = New-ToolkitFinding `
            -Name "Microsoft Defender Antivirus" `
            -Type "Software" `
            -Vendor "Microsoft" `
            -Category "Security" `
            -Recommendation "Review / likely disable" `
            -Risk "Low" `
            -Reason "Test safety boundary." `
            -Source "Installed software" `
            -Version "" `
            -State "Installed"

        $entry = ConvertTo-ToolkitOptimizationPlanEntry -Finding $protectedFinding

        $entry.ActionId | Should -Be "protected-retain"
        $entry.PlanStatus | Should -Be "Protected"
        $entry.ProposedAction | Should -Be "Retain without optimization"
    }

    It "retains required and critical findings as core safety boundaries" {
        $coreFinding = New-ToolkitFinding `
            -Name "Core platform service" `
            -Type "Service" `
            -Vendor "Microsoft" `
            -Category "Required" `
            -Recommendation "Review / likely disable" `
            -Risk "Critical" `
            -Reason "Test safety boundary." `
            -Source "Windows Service" `
            -Version "" `
            -State "Running"

        (ConvertTo-ToolkitOptimizationPlanEntry -Finding $coreFinding).ActionId |
            Should -Be "protected-retain"
    }

    It "preserves finding confidence when it is available" {
        $findingWithConfidence = $ReviewFinding | Select-Object *
        $findingWithConfidence | Add-Member -NotePropertyName Confidence -NotePropertyValue "High"

        (ConvertTo-ToolkitOptimizationPlanEntry -Finding $findingWithConfidence).Confidence |
            Should -Be "High"
    }

    It "writes CSV and JSON optimization plan reports" {
        $plan = @(New-ToolkitOptimizationPlan -Findings @($ReviewFinding))
        $paths = Save-ToolkitOptimizationPlanReports -Plan $plan

        Test-Path $paths.CsvPath | Should -BeTrue
        Test-Path $paths.JsonPath | Should -BeTrue
        (Import-Csv $paths.CsvPath)[0].PlanId | Should -Be $plan[0].PlanId
        (Get-Content $paths.JsonPath -Raw | ConvertFrom-Json)[0].SourceFindingId |
            Should -Be $plan[0].SourceFindingId
    }

    It "writes explicit empty plan reports when no findings are available" {
        $paths = Save-ToolkitOptimizationPlanReports -Plan @()

        Test-Path $paths.CsvPath | Should -BeTrue
        Test-Path $paths.JsonPath | Should -BeTrue
        (Get-Content $paths.CsvPath -Raw) | Should -Match "PlanId"
        (Get-Content $paths.JsonPath -Raw | ConvertFrom-Json).Count | Should -Be 0
    }

    It "does not add optimizer reports back into the source finding set" {
        $reportPath = Join-Path $TestDrive "ReportInput"
        New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
        @($ReviewFinding) | Export-Csv -Path (Join-Path $reportPath "Software_Report.csv") -NoTypeInformation
        @((New-ToolkitOptimizationPlan -Findings @($ReviewFinding))) |
            Export-Csv -Path (Join-Path $reportPath "Optimization_Plan.csv") -NoTypeInformation

        Import-Module "$Root\Core\Summary.psm1" -Force
        @(Get-ToolkitReportFindings -ReportPath $reportPath).Count | Should -Be 1
    }
}

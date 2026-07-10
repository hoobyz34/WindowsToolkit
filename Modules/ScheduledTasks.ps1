$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Models.psm1" -Force
Import-Module "$Root\Core\Discovery.psm1" -Force
Import-Module "$Root\Core\Recommendation.psm1" -Force

Write-Section "Scheduled Task Analyzer"

$findings = foreach ($task in Get-ToolkitScheduledTasks) {
    $text = "$($task.TaskName) $($task.TaskPath) $($task.Author) $($task.Description)"

    $recommendation = Get-ToolkitRecommendation `
        -Text $text `
        -Type "ScheduledTask"

    New-ToolkitFinding `
        -Name $task.TaskName `
        -Type "ScheduledTask" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source $task.TaskPath `
        -Version "" `
        -State $task.State
}

Save-CsvReport `
    -Name "ScheduledTasks_Report" `
    -Data $findings

Write-Success "Scheduled Task Analyzer complete."
Write-Host "Items analyzed: $($findings.Count)"
Write-Host "Report saved to: $Global:ToolkitRunPath\ScheduledTasks_Report.csv"
$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Models.psm1" -Force
Import-Module "$Root\Core\Discovery.psm1" -Force
Import-Module "$Root\Core\Recommendation.psm1" -Force

Write-Section "Startup Analyzer"

$findings = @()

foreach ($startupCommand in Get-ToolkitStartupCommands) {
    $text = @(
        $startupCommand.Name
        $startupCommand.Command
        $startupCommand.Location
        $startupCommand.User
    ) -join " "

    $recommendation = Get-ToolkitRecommendation `
        -Text $text `
        -Name $startupCommand.Name `
        -Type "general"

    $findings += New-ToolkitFinding `
        -Name $startupCommand.Name `
        -Type "Startup Command" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source $startupCommand.Location `
        -Version "" `
        -State $startupCommand.Setting
}

foreach ($task in Get-ToolkitScheduledTasks) {
    $triggerText = $task.Triggers | Out-String

    if ($triggerText -notmatch "AtLogOn|AtStartup|Logon|Startup") {
        continue
    }

    $name = "$($task.TaskPath)$($task.TaskName)"
    $text = @(
        $name
        $task.Author
        $triggerText
    ) -join " "

    $recommendation = Get-ToolkitRecommendation `
        -Text $text `
        -Name $name `
        -Type "general"

    $findings += New-ToolkitFinding `
        -Name $name `
        -Type "Scheduled Task" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source "Scheduled Task" `
        -Version "" `
        -State "Startup Trigger"
}

foreach ($service in Get-ToolkitServices | Where-Object { $_.StartMode -eq "Auto" }) {
    $name = if ($service.DisplayName) {
        $service.DisplayName
    }
    else {
        $service.Name
    }

    $text = @(
        $service.Name
        $service.DisplayName
        $service.PathName
    ) -join " "

    $recommendation = Get-ToolkitRecommendation `
        -Text $text `
        -Name $name `
        -Type "service"

    $findings += New-ToolkitFinding `
        -Name $name `
        -Type "Automatic Service" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source "Windows Service" `
        -Version "" `
        -State $service.State
}

$reportPath = Save-CsvReport `
    -Name "Startup_Analyzer" `
    -Data $findings

Write-Success "Startup Analyzer complete."
Write-Host "Startup items analyzed: $($findings.Count)"
Write-Host "Report saved to: $reportPath"

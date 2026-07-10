$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Models.psm1" -Force
Import-Module "$Root\Core\Discovery.psm1" -Force
Import-Module "$Root\Core\Recommendation.psm1" -Force

Write-Section "Windows Features Analyzer"

$findings = foreach ($feature in Get-ToolkitWindowsFeatures) {
    $text = "$($feature.FeatureName) $($feature.State)"

    $recommendation = Get-ToolkitRecommendation `
        -Text $text `
        -Type "WindowsFeature"

    New-ToolkitFinding `
        -Name $feature.FeatureName `
        -Type "WindowsFeature" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source "Windows Optional Feature" `
        -Version "" `
        -State $feature.State
}

Save-CsvReport `
    -Name "WindowsFeatures_Report" `
    -Data $findings

Write-Success "Windows Features Analyzer complete."
Write-Host "Items analyzed: $($findings.Count)"
Write-Host "Report saved to: $Global:ToolkitRunPath\WindowsFeatures_Report.csv"
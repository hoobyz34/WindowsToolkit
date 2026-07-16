$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Models.psm1" -Force
Import-Module "$Root\Core\Discovery.psm1" -Force
Import-Module "$Root\Core\Recommendation.psm1" -Force

Write-Section "Service Analyzer"

$findings = foreach ($service in Get-ToolkitServices) {
    $text = "$($service.Name) $($service.DisplayName) $($service.PathName)"

    $recommendation = Get-ToolkitRecommendation `
        -Text $text `
        -Type service

    New-ToolkitFinding `
        -Name $service.DisplayName `
        -Type "Service" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source "Windows Service" `
        -Version "" `
        -State $service.State `
        -ServiceName $service.Name `
        -ServiceDisplayName $service.DisplayName `
        -StartupType $service.StartupType `
        -Dependencies $service.Dependencies `
        -RecoveryConfiguration $service.RecoveryConfiguration
}

Save-CsvReport `
    -Name "Service_Analyzer" `
    -Data $findings

Write-Success "Service Analyzer complete."
Write-Host "Report saved to: $Global:ToolkitRunPath\Service_Analyzer.csv"

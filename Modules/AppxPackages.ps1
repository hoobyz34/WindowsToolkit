$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Models.psm1" -Force
Import-Module "$Root\Core\Discovery.psm1" -Force
Import-Module "$Root\Core\Recommendation.psm1" -Force

Write-Section "Appx Package Analyzer"

$findings = foreach ($package in Get-ToolkitAppxPackages) {

    $text = "$($package.Name) $($package.PublisherDisplayName)"

    $recommendation = Get-ToolkitRecommendation `
        -Text $text `
        -Type "AppxPackage"

    New-ToolkitFinding `
        -Name $package.Name `
        -Type "AppxPackage" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source "Microsoft Store" `
        -Version $package.Version `
        -State "Installed"
}

Save-CsvReport `
    -Name "AppxPackages_Report" `
    -Data $findings

Write-Success "Appx Package Analyzer complete."
Write-Host "Items analyzed: $($findings.Count)"
Write-Host "Report saved to: $Global:ToolkitRunPath\AppxPackages_Report.csv"
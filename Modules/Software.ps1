$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Models.psm1" -Force
Import-Module "$Root\Core\Discovery.psm1" -Force
Import-Module "$Root\Core\Recommendation.psm1" -Force

Write-Section "Installed Software Analyzer"

$software = @(
    Get-ToolkitInstalledSoftware |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace(
                [string]$_.DisplayName
            )
        } |
        Sort-Object `
            DisplayName,
            DisplayVersion,
            Publisher `
            -Unique
)

$findings = foreach ($item in $software) {
    $text = @(
        $item.DisplayName
        $item.Publisher
        $item.DisplayVersion
        $item.InstallLocation
        $item.UninstallString
    ) -join " "

    $recommendation = Get-ToolkitRecommendation `
        -Text $text `
        -Type "Software"

    $source = if ($item.PSPath) {
        $item.PSPath
    }
    elseif ($item.InstallLocation) {
        $item.InstallLocation
    }
    else {
        "Windows Uninstall Registry"
    }

    New-ToolkitFinding `
        -Name $item.DisplayName `
        -Type "Software" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source $source `
        -Version $item.DisplayVersion `
        -State "Installed"
}

$reportPath = Save-CsvReport `
    -Name "Software_Analyzer" `
    -Data $findings

Write-Success "Installed Software Analyzer complete."
Write-Host "Programs analyzed: $($findings.Count)"
Write-Host "Report saved to: $reportPath"

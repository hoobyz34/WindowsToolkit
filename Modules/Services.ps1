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
    $serviceSnapshot = if (
        $recommendation.Recommendation -eq "Review / likely disable"
    ) {
        Get-ToolkitServiceInventoryRecord `
            -Name $service.Name `
            -IncludeExecutableIdentity
    }
    else {
        $service
    }

    New-ToolkitFinding `
        -Name $serviceSnapshot.DisplayName `
        -Type "Service" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source "Windows Service" `
        -Version "" `
        -State $serviceSnapshot.State `
        -ServiceName $serviceSnapshot.Name `
        -ServiceDisplayName $serviceSnapshot.DisplayName `
        -StartupType $serviceSnapshot.StartupType `
        -ServicePath $serviceSnapshot.PathName `
        -ServiceStartName $serviceSnapshot.StartName `
        -ServiceType $serviceSnapshot.ServiceType `
        -DelayedAutoStartConfiguration $serviceSnapshot.DelayedAutoStartConfiguration `
        -Dependencies $serviceSnapshot.Dependencies `
        -DependentServices $serviceSnapshot.DependentServices `
        -ExecutablePath $serviceSnapshot.ExecutablePath `
        -ExecutableCompany $serviceSnapshot.ExecutableCompany `
        -ExecutableProduct $serviceSnapshot.ExecutableProduct `
        -ExecutableSignatureStatus $serviceSnapshot.ExecutableSignatureStatus `
        -ExecutableSignerSubject $serviceSnapshot.ExecutableSignerSubject `
        -RecoveryConfiguration $serviceSnapshot.RecoveryConfiguration
}

Save-CsvReport `
    -Name "Service_Analyzer" `
    -Data $findings

Write-Success "Service Analyzer complete."
Write-Host "Report saved to: $Global:ToolkitRunPath\Service_Analyzer.csv"

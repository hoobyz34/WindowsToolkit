$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Models.psm1" -Force
Import-Module "$Root\Core\Discovery.psm1" -Force
Import-Module "$Root\Core\Recommendation.psm1" -Force

Write-Section "Driver Analyzer"

$findings = foreach ($driver in Get-ToolkitDrivers) {
    $name = if ($driver.DeviceName) { $driver.DeviceName } else { "Unknown Driver" }

    $text = "$($driver.DeviceName) $($driver.Manufacturer) $($driver.DriverProviderName) $($driver.InfName)"

    $recommendation = Get-ToolkitRecommendation `
        -Text $text `
        -Type driver

    New-ToolkitFinding `
        -Name $name `
        -Type "Driver" `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source $driver.InfName `
        -Version $driver.DriverVersion `
        -State $driver.DeviceClass
}

Save-CsvReport `
    -Name "Driver_Analyzer" `
    -Data $findings

Write-Success "Driver Analyzer complete."
Write-Host "Drivers analyzed: $($findings.Count)"
Write-Host "Report saved to: $Global:ToolkitRunPath\Driver_Analyzer.csv"
Import-Module "C:\WindowsToolkit\Core\Logger.psm1" -Force
Import-Module "C:\WindowsToolkit\Core\Reporting.psm1" -Force

Write-Log "Starting Service Analyzer."

$services = Get-CimInstance Win32_Service | ForEach-Object {
    [pscustomobject]@{
        Name           = $_.Name
        DisplayName    = $_.DisplayName
        State          = $_.State
        StartMode      = $_.StartMode
        PathName       = $_.PathName
        Description    = $_.Description
        Recommendation = "Review"
        Reason         = "Initial analyzer pass; no changes made."
    }
}

Save-CsvReport "Service_Analyzer" $services

Write-Log "Service Analyzer complete."
Write-Host "Report saved to: $Global:ToolkitRunPath\Service_Analyzer.csv"
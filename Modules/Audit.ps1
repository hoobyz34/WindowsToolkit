Import-Module "C:\WindowsToolkit\Core\Logger.psm1" -Force
Import-Module "C:\WindowsToolkit\Core\Utility.psm1" -Force
Import-Module "C:\WindowsToolkit\Core\Reporting.psm1" -Force

Write-Log "Starting System Audit module."

if (-not (Test-IsAdmin)) {
    Write-Log "WARNING: PowerShell is not running as Administrator. Some reports may be incomplete."
}

Save-TextReport "01_Windows_Info" {
    Get-ComputerInfo |
    Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture,
    CsManufacturer, CsModel, CsSystemType, BiosManufacturer, BiosVersion,
    BiosReleaseDate, CsNumberOfLogicalProcessors, CsTotalPhysicalMemory
}

Save-TextReport "02_Disks" {
    Get-Disk | Format-Table -AutoSize
    "`nVolumes:"
    Get-Volume | Format-Table -AutoSize
}

Save-TextReport "03_Device_Manager_Problems" {
    Get-PnpDevice |
    Where-Object Status -ne "OK" |
    Format-Table Class, FriendlyName, Status, Problem, InstanceId -AutoSize
}

Save-TextReport "04_Services" {
    Get-Service |
    Select-Object Name, DisplayName, Status, StartType |
    Sort-Object StartType, Name |
    Format-Table -AutoSize
}

Save-TextReport "05_Startup_Items" {
    Get-CimInstance Win32_StartupCommand |
    Select-Object Name, Command, Location, User |
    Format-Table -AutoSize
}

Save-TextReport "06_Scheduled_Tasks" {
    Get-ScheduledTask |
    Select-Object TaskName, TaskPath, State, Author |
    Sort-Object TaskPath, TaskName |
    Format-Table -AutoSize
}

Save-TextReport "07_Defender" {
    Get-MpComputerStatus | Format-List *
}

Save-TextReport "08_EventViewer_System_Errors" {
    Get-WinEvent -FilterHashtable @{
        LogName='System'
        Level=1,2
        StartTime=(Get-Date).AddDays(-7)
    } -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message |
    Format-List
}

Write-Log "System Audit module complete."
Write-Host ""
Write-Host "Audit saved to: $Global:ToolkitRunPath"

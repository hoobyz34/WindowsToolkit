if (-not $Global:ToolkitRoot) {
    $Global:ToolkitRoot = "C:\WindowsToolkit"
}

if (-not $Global:ToolkitTimestamp) {
    $Global:ToolkitTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
}

if (-not $Global:ToolkitRunPath) {
    $Global:ToolkitRunPath = Join-Path $Global:ToolkitRoot "Reports\Run_$Global:ToolkitTimestamp"
}

if (-not $Global:ToolkitLogPath) {
    $Global:ToolkitLogPath = Join-Path $Global:ToolkitRoot "Logs\Run_$Global:ToolkitTimestamp.log"
}

function Initialize-ToolkitSession {
    New-Item -ItemType Directory -Path $Global:ToolkitRunPath -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $Global:ToolkitLogPath) -Force | Out-Null
    Start-Transcript -Path $Global:ToolkitLogPath -Append | Out-Null
    Write-Log "Toolkit session initialized."
}

function Write-Log {
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
}

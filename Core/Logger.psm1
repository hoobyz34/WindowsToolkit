if (-not $Global:ToolkitTimestamp) {
    $Global:ToolkitTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
}

function Initialize-ToolkitSession {
    if (-not $Global:ToolkitRoot) {
        $Global:ToolkitRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    }

    $Global:ToolkitRunPath = Join-Path $Global:ToolkitRoot "Reports\Run_$Global:ToolkitTimestamp"
    $Global:ToolkitLogPath = Join-Path $Global:ToolkitRoot "Logs\Run_$Global:ToolkitTimestamp.log"

    New-Item -ItemType Directory -Path $Global:ToolkitRunPath -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $Global:ToolkitLogPath) -Force | Out-Null

    Start-Transcript -Path $Global:ToolkitLogPath -Append | Out-Null
    Write-Log "Toolkit session initialized."
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpper(), $Message
    Write-Host $line
}
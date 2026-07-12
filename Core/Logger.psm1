function Initialize-ToolkitSession {
    [CmdletBinding()]
    param(
        [string]$Timestamp = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    )

    $Global:ToolkitRoot = Split-Path -Parent $PSScriptRoot
    $Global:ToolkitTimestamp = $Timestamp

    $Global:ToolkitRunPath = Join-Path `
        $Global:ToolkitRoot `
        "Reports\Run_$Global:ToolkitTimestamp"

    $Global:ToolkitLogPath = Join-Path `
        $Global:ToolkitRoot `
        "Logs\Run_$Global:ToolkitTimestamp.log"

    New-Item `
        -ItemType Directory `
        -Path $Global:ToolkitRunPath `
        -Force |
        Out-Null

    New-Item `
        -ItemType Directory `
        -Path (Split-Path $Global:ToolkitLogPath) `
        -Force |
        Out-Null

    Start-Transcript `
        -Path $Global:ToolkitLogPath `
        -Append |
        Out-Null

    Write-Log "Toolkit session initialized."
}

function Stop-ToolkitSession {
    [CmdletBinding()]
    param()

    Write-Log "Toolkit session completed."

    try {
        Stop-Transcript |
            Out-Null
    }
    catch {
        # No active transcript. Nothing to stop.
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $line = "[{0}] [{1}] {2}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $Level.ToUpper(),
        $Message

    Write-Host $line
}

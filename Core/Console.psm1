function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

function Show-ToolkitHeader {
    Clear-Host

    $version = Get-ToolkitVersion

    Write-Host "=====================================================" -ForegroundColor DarkGray
    Write-Host "              WindowsToolkit v$version" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor DarkGray
    Write-Host ""
}

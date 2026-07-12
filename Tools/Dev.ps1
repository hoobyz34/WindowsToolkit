[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Test", "Verify", "Commit", "Sync")]
    [string]$Action,

    [string]$Message,

    [string[]]$Paths
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Invoke-ToolkitTests {
    Write-Host ""
    Write-Host "Running WindowsToolkit tests..."
    Write-Host ""

    & "$Root\Tests\RunTests.ps1"

    if ($LASTEXITCODE -ne 0) {
        throw "Test execution failed."
    }
}

function Test-ToolkitGitDiff {
    git diff --check

    if ($LASTEXITCODE -ne 0) {
        throw "Git found whitespace errors."
    }
}

switch ($Action) {
    "Test" {
        Invoke-ToolkitTests
    }

    "Verify" {
        Invoke-ToolkitTests
        Test-ToolkitGitDiff

        Write-Host ""
        git status
    }

    "Commit" {
        if (-not $Message) {
            throw "Commit requires -Message."
        }

        if (-not $Paths -or $Paths.Count -eq 0) {
            throw "Commit requires -Paths so unrelated files are not staged."
        }

        Invoke-ToolkitTests
        Test-ToolkitGitDiff

        git add -- $Paths

        git diff --cached --quiet

        if ($LASTEXITCODE -eq 0) {
            throw "No staged changes were found."
        }

        git commit -m $Message

        if ($LASTEXITCODE -ne 0) {
            throw "Git commit failed."
        }

        $branch = git branch --show-current

        git push origin $branch

        if ($LASTEXITCODE -ne 0) {
            throw "Git push failed."
        }

        Write-Host ""
        Write-Host "Committed and pushed successfully."
        git status
    }

    "Sync" {
        if (git status --porcelain) {
            throw "Working tree must be clean before syncing."
        }

        git pull --ff-only

        if ($LASTEXITCODE -ne 0) {
            throw "Git pull failed."
        }

        $branch = git branch --show-current
        git push origin $branch

        if ($LASTEXITCODE -ne 0) {
            throw "Git push failed."
        }

        Write-Host ""
        git status
    }
}

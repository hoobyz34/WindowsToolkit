<#
.SYNOPSIS
    Loads WindowsToolkit configuration profiles.
#>

function Get-ToolkitConfiguration {
    param(
        [string]$ProfileName = "HP_ZBook_Fury_G7.json"
    )

    $root = Split-Path -Parent $PSScriptRoot
    $profilePath = Join-Path $root "Profiles\$ProfileName"

    if (-not (Test-Path $profilePath)) {
        throw "Profile not found: $profilePath"
    }

    return Get-Content $profilePath -Raw | ConvertFrom-Json
}
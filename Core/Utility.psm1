function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ToolkitRoot {
    if ($Global:ToolkitRoot) {
        return $Global:ToolkitRoot
    }

    $current = Get-Location

    while ($current) {
        if (Test-Path (Join-Path $current ".git")) {
            $Global:ToolkitRoot = $current.Path
            return $Global:ToolkitRoot
        }

        $parent = Split-Path $current -Parent

        if (-not $parent -or $parent -eq $current.Path) {
            break
        }

        $current = Get-Item $parent
    }

    throw "Could not determine WindowsToolkit root."
}

function Get-ToolkitPath {
    param([string]$RelativePath)

    return Join-Path (Get-ToolkitRoot) $RelativePath
}
function Get-ToolkitDataFile {
    param([string]$FileName)

    $root = Split-Path -Parent $PSScriptRoot
    $path = Join-Path $root "Data\$FileName"

    if (-not (Test-Path $path)) {
        throw "Data file not found: $path"
    }

    return Get-Content $path -Raw | ConvertFrom-Json
}

function Find-ToolkitRuleMatch {
    param(
        [string]$Text,
        [string]$RuleFile
    )

    $rules = Get-ToolkitDataFile -FileName $RuleFile

    foreach ($rule in $rules) {
        if ($rule.match -and $Text -match [regex]::Escape($rule.match)) {
            return $rule
        }

        if ($rule.patterns) {
            foreach ($pattern in $rule.patterns) {
                if ($Text -match [regex]::Escape($pattern)) {
                    return $rule
                }
            }
        }
    }

    return $null
}

function Get-ToolkitVendor {
    param([string]$Text)

    $vendors = Get-ToolkitDataFile -FileName "Vendors.json"

    foreach ($vendor in $vendors) {
        foreach ($pattern in $vendor.patterns) {
            if ($Text -match [regex]::Escape($pattern)) {
                return $vendor.name
            }
        }
    }

    return "Unknown"
}

function Get-ToolkitRecommendation {
    param(
        [string]$Text,
        [string]$Type = "general"
    )

    $specificFile = switch ($Type) {
        "service"  { "Services.json" }
        "software" { "Software.json" }
        "driver"   { "Drivers.json" }
        default    { "Rules.json" }
    }

    $match = Find-ToolkitRuleMatch -Text $Text -RuleFile $specificFile

    if (-not $match) {
        $match = Find-ToolkitRuleMatch -Text $Text -RuleFile "Rules.json"
    }

    if ($match) {
        return [pscustomobject]@{
            Vendor         = if ($match.vendor) { $match.vendor } else { Get-ToolkitVendor $Text }
            Category       = if ($match.category) { $match.category } else { "General" }
            Recommendation = if ($match.recommendation) { $match.recommendation } else { $match.action }
            Risk           = if ($match.risk) { $match.risk } else { "Unknown" }
            Reason         = $match.reason
        }
    }

    return [pscustomobject]@{
        Vendor         = Get-ToolkitVendor $Text
        Category       = "Unknown"
        Recommendation = "Review"
        Risk           = "Unknown"
        Reason         = "No matching recommendation rule."
    }
}
function Get-ToolkitCorrelationRules {
    [CmdletBinding()]
    param(
        [string]$Path
    )

    if (-not $Path) {
        $root = Split-Path -Parent $PSScriptRoot
        $Path = Join-Path $root "Data\Correlations.json"
    }

    if (-not (Test-Path $Path)) {
        throw "Correlation data file not found: $Path"
    }

    return @(
        Get-Content `
            -Path $Path `
            -Raw |
            ConvertFrom-Json `
                -ErrorAction Stop
    )
}

function Get-ToolkitFindingSearchText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Finding
    )

    return @(
        $Finding.Name
        $Finding.Type
        $Finding.Vendor
        $Finding.Category
        $Finding.Recommendation
        $Finding.Risk
        $Finding.Reason
        $Finding.Source
        $Finding.Version
        $Finding.State
        $Finding.ReportFile
    ) -join " "
}

function Find-ToolkitCorrelationMatches {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Findings,

        [AllowNull()]
        [object]$Condition
    )

    if ($null -eq $Condition) {
        return @()
    }

    $matches = foreach ($finding in @($Findings)) {
        if ($null -eq $finding) {
            continue
        }

        if (
            $Condition.type -and
            [string]$finding.Type -ne [string]$Condition.type
        ) {
            continue
        }

        if (
            $Condition.vendor -and
            [string]$finding.Vendor -notmatch [string]$Condition.vendor
        ) {
            continue
        }

        if (
            $Condition.statePattern -and
            [string]$finding.State -notmatch (
                [string]$Condition.statePattern
            )
        ) {
            continue
        }

        if (
            $Condition.recommendationPattern -and
            [string]$finding.Recommendation -notmatch (
                [string]$Condition.recommendationPattern
            )
        ) {
            continue
        }

        if ($Condition.pattern) {
            $pattern = [string]$Condition.pattern
            $name = [string]$finding.Name
            $searchText = Get-ToolkitFindingSearchText `
                -Finding $finding

            # Test Name separately so anchored expressions such as
            # ^VirtualMachinePlatform$ work correctly.
            if (
                $name -notmatch $pattern -and
                $searchText -notmatch $pattern
            ) {
                continue
            }
        }

        $finding
    }

    return @($matches)
}

function Test-ToolkitCorrelationCondition {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Findings,

        [AllowNull()]
        [object]$Condition
    )

    if ($null -eq $Condition) {
        return $false
    }

    $minimum = if ($null -ne $Condition.minCount) {
        [int]$Condition.minCount
    }
    else {
        1
    }

    $matches = @(
        Find-ToolkitCorrelationMatches `
            -Findings $Findings `
            -Condition $Condition
    )

    return $matches.Count -ge $minimum
}

function Get-ToolkitValidConditions {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Conditions
    )

    return @(
        @($Conditions) |
            Where-Object {
                $null -ne $_
            }
    )
}

function Test-ToolkitRequiredTypes {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Findings,

        [AllowEmptyCollection()]
        [string[]]$RequiredTypes
    )

    foreach ($type in @($RequiredTypes)) {
        if ([string]::IsNullOrWhiteSpace($type)) {
            continue
        }

        $matchingItems = @(
            $Findings |
                Where-Object {
                    [string]$_.Type -eq $type
                }
        )

        if ($matchingItems.Count -eq 0) {
            return $false
        }
    }

    return $true
}

function Invoke-ToolkitCorrelation {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Findings,

        [object[]]$Rules = (Get-ToolkitCorrelationRules)
    )

    $sourceFindings = @(
        $Findings |
            Where-Object {
                $null -ne $_ -and
                [string]$_.Type -ne "Correlation"
            }
    )

    $results = foreach ($rule in @($Rules)) {
        if ($null -eq $rule) {
            continue
        }

        $requiredTypes = @(
            @($rule.requiresTypes) |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                }
        )

        if (
            -not (
                Test-ToolkitRequiredTypes `
                    -Findings $sourceFindings `
                    -RequiredTypes $requiredTypes
            )
        ) {
            continue
        }

        $allConditions = @(
            Get-ToolkitValidConditions `
                -Conditions $rule.all
        )

        $anyConditions = @(
            Get-ToolkitValidConditions `
                -Conditions $rule.any
        )

        $noneConditions = @(
            Get-ToolkitValidConditions `
                -Conditions $rule.none
        )

        $allPassed = $true

        foreach ($condition in $allConditions) {
            if (
                -not (
                    Test-ToolkitCorrelationCondition `
                        -Findings $sourceFindings `
                        -Condition $condition
                )
            ) {
                $allPassed = $false
                break
            }
        }

        if (-not $allPassed) {
            continue
        }

        if ($anyConditions.Count -gt 0) {
            $anyPassed = $false

            foreach ($condition in $anyConditions) {
                if (
                    Test-ToolkitCorrelationCondition `
                        -Findings $sourceFindings `
                        -Condition $condition
                ) {
                    $anyPassed = $true
                    break
                }
            }

            if (-not $anyPassed) {
                continue
            }
        }

        $nonePassed = $true

        foreach ($condition in $noneConditions) {
            if (
                Test-ToolkitCorrelationCondition `
                    -Findings $sourceFindings `
                    -Condition $condition
            ) {
                $nonePassed = $false
                break
            }
        }

        if (-not $nonePassed) {
            continue
        }

        $evidence = [System.Collections.Generic.List[object]]::new()

        $evidenceConditions = @(
            $allConditions
            $anyConditions
        )

        foreach ($condition in $evidenceConditions) {
            $conditionMatches = @(
                Find-ToolkitCorrelationMatches `
                    -Findings $sourceFindings `
                    -Condition $condition
            )

            foreach ($match in $conditionMatches) {
                $alreadyAdded = @(
                    $evidence |
                        Where-Object {
                            [string]$_.Name -eq [string]$match.Name -and
                            [string]$_.Type -eq [string]$match.Type
                        }
                ).Count -gt 0

                if (-not $alreadyAdded) {
                    $evidence.Add($match)
                }
            }
        }

        $evidenceNames = @(
            $evidence |
                ForEach-Object {
                    [string]$_.Name
                } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                } |
                Select-Object -Unique
        )

        $source = if ($evidenceNames.Count -gt 0) {
            $evidenceNames -join "; "
        }
        else {
            "Cross-analyzer inventory"
        }

        [PSCustomObject]@{
            Name           = [string]$rule.name
            Type           = "Correlation"
            Vendor         = if ($rule.vendor) {
                [string]$rule.vendor
            }
            else {
                "Multiple"
            }
            Category       = [string]$rule.category
            Recommendation = [string]$rule.recommendation
            Risk           = [string]$rule.risk
            Reason         = [string]$rule.reason
            Source         = $source
            Version        = ""
            State          = "Observed"
            CorrelationId  = [string]$rule.id
            EvidenceCount  = $evidence.Count
        }
    }

    return @($results)
}

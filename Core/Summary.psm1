function Get-ToolkitReportFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ReportPath
    )

    if (-not (Test-Path $ReportPath)) {
        return @()
    }

    $excludedReports = @(
        "Inventory_Summary.csv"
        "Inventory_Summary_Details.csv"
    )

    $findings = foreach (
        $file in Get-ChildItem `
            -Path $ReportPath `
            -Filter "*.csv" `
            -File |
            Where-Object {
                $_.Name -notin $excludedReports
            }
    ) {
        $rows = @(
            Import-Csv `
                -Path $file.FullName `
                -ErrorAction Stop
        )

        foreach ($row in $rows) {
            $row |
                Add-Member `
                    -NotePropertyName ReportFile `
                    -NotePropertyValue $file.Name `
                    -Force

            $row
        }
    }

    return @($findings)
}

function ConvertTo-ToolkitCountList {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter(Mandatory)]
        [string]$Property,

        [string]$UnknownValue = "Unknown"
    )

    $normalized = foreach ($item in @($Items)) {
        $value = $item.$Property

        if ([string]::IsNullOrWhiteSpace([string]$value)) {
            $value = $UnknownValue
        }

        [PSCustomObject]@{
            Value = [string]$value
        }
    }

    return @(
        $normalized |
            Group-Object Value |
            Sort-Object `
                -Property @(
                    @{
                        Expression = "Count"
                        Descending = $true
                    }
                    @{
                        Expression = "Name"
                        Descending = $false
                    }
                ) |
            ForEach-Object {
                [PSCustomObject]@{
                    Name  = $_.Name
                    Count = $_.Count
                }
            }
    )
}

function Get-ToolkitInventorySummary {
    [CmdletBinding()]
    param(
        [string]$ReportPath
    )

    if (-not $ReportPath) {
        $ReportPath = Get-ToolkitReportPath
    }

    $findings = @(
        Get-ToolkitReportFindings `
            -ReportPath $ReportPath
    )

    $reportFiles = @(
        Get-ChildItem `
            -Path $ReportPath `
            -Filter "*.csv" `
            -File `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -notin @(
                    "Inventory_Summary.csv"
                    "Inventory_Summary_Details.csv"
                )
            } |
            Sort-Object Name |
            ForEach-Object {
                [PSCustomObject]@{
                    Name     = $_.Name
                    ItemCount = @(
                        Import-Csv `
                            -Path $_.FullName `
                            -ErrorAction SilentlyContinue
                    ).Count
                }
            }
    )

    return [PSCustomObject]@{
        GeneratedAt     = Get-Date
        ReportPath      = $ReportPath
        ReportCount     = $reportFiles.Count
        TotalItems      = $findings.Count
        Reports         = $reportFiles
        Types           = ConvertTo-ToolkitCountList `
            -Items $findings `
            -Property "Type"
        Vendors         = ConvertTo-ToolkitCountList `
            -Items $findings `
            -Property "Vendor"
        Categories      = ConvertTo-ToolkitCountList `
            -Items $findings `
            -Property "Category"
        Recommendations = ConvertTo-ToolkitCountList `
            -Items $findings `
            -Property "Recommendation"
        Risks           = ConvertTo-ToolkitCountList `
            -Items $findings `
            -Property "Risk"
    }
}

function ConvertTo-ToolkitSummaryRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Summary
    )

    $rows = @(
        [PSCustomObject]@{
            Section = "Overview"
            Name    = "Reports"
            Count   = $Summary.ReportCount
        }

        [PSCustomObject]@{
            Section = "Overview"
            Name    = "Total Items"
            Count   = $Summary.TotalItems
        }
    )

    foreach ($sectionName in @(
        "Reports"
        "Types"
        "Vendors"
        "Categories"
        "Recommendations"
        "Risks"
    )) {
        foreach ($item in @($Summary.$sectionName)) {
            $name = if ($sectionName -eq "Reports") {
                $item.Name
            }
            else {
                $item.Name
            }

            $count = if ($sectionName -eq "Reports") {
                $item.ItemCount
            }
            else {
                $item.Count
            }

            $rows += [PSCustomObject]@{
                Section = $sectionName
                Name    = $name
                Count   = $count
            }
        }
    }

    return $rows
}


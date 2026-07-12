function ConvertTo-ToolkitHtmlEncoded {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    return [System.Net.WebUtility]::HtmlEncode(
        [string]$Value
    )
}

function ConvertTo-ToolkitHtmlTable {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Data,

        [Parameter(Mandatory)]
        [string[]]$Properties,

        [string]$EmptyMessage = "No data available."
    )

    if (@($Data).Count -eq 0) {
        return @"
<div class="empty-state">
    $(
        ConvertTo-ToolkitHtmlEncoded `
            -Value $EmptyMessage
    )
</div>
"@
    }

    $headerCells = foreach ($property in $Properties) {
        "<th>$(ConvertTo-ToolkitHtmlEncoded -Value $property)</th>"
    }

    $rows = foreach ($item in @($Data)) {
        $cells = foreach ($property in $Properties) {
            $value = $item.$property

            "<td>$(ConvertTo-ToolkitHtmlEncoded -Value $value)</td>"
        }

        "<tr>$($cells -join '')</tr>"
    }

    return @"
<div class="table-wrap">
<table>
    <thead>
        <tr>$($headerCells -join '')</tr>
    </thead>
    <tbody>
        $($rows -join [Environment]::NewLine)
    </tbody>
</table>
</div>
"@
}

function ConvertTo-ToolkitDashboardSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Content,

        [string]$Subtitle = ""
    )

    $subtitleHtml = if ($Subtitle) {
        "<p class=`"section-subtitle`">$(ConvertTo-ToolkitHtmlEncoded -Value $Subtitle)</p>"
    }
    else {
        ""
    }

    return @"
<section class="panel">
    <div class="section-header">
        <h2>$(ConvertTo-ToolkitHtmlEncoded -Value $Title)</h2>
        $subtitleHtml
    </div>
    $Content
</section>
"@
}

function New-ToolkitHtmlDashboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Summary,

        [string]$ToolkitVersion = "Unknown",

        [string]$ComputerName = $env:COMPUTERNAME
    )

    $generatedAt = if ($Summary.GeneratedAt) {
        Get-Date $Summary.GeneratedAt -Format "yyyy-MM-dd HH:mm:ss"
    }
    else {
        Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $reportsTable = ConvertTo-ToolkitHtmlTable `
        -Data @($Summary.Reports) `
        -Properties @(
            "Name"
            "ItemCount"
        ) `
        -EmptyMessage "No analyzer reports were found."

    $typesTable = ConvertTo-ToolkitHtmlTable `
        -Data @($Summary.Types) `
        -Properties @(
            "Name"
            "Count"
        )

    $vendorsTable = ConvertTo-ToolkitHtmlTable `
        -Data @(
            $Summary.Vendors |
                Select-Object -First 20
        ) `
        -Properties @(
            "Name"
            "Count"
        )

    $categoriesTable = ConvertTo-ToolkitHtmlTable `
        -Data @($Summary.Categories) `
        -Properties @(
            "Name"
            "Count"
        )

    $recommendationsTable = ConvertTo-ToolkitHtmlTable `
        -Data @($Summary.Recommendations) `
        -Properties @(
            "Name"
            "Count"
        )

    $risksTable = ConvertTo-ToolkitHtmlTable `
        -Data @($Summary.Risks) `
        -Properties @(
            "Name"
            "Count"
        )

    $sections = @(
        ConvertTo-ToolkitDashboardSection `
            -Title "Analyzer Reports" `
            -Subtitle "CSV reports included in this run." `
            -Content $reportsTable

        ConvertTo-ToolkitDashboardSection `
            -Title "Inventory Types" `
            -Subtitle "Inventory items grouped by analyzer type." `
            -Content $typesTable

        ConvertTo-ToolkitDashboardSection `
            -Title "Top Vendors" `
            -Subtitle "The twenty most frequently identified vendors." `
            -Content $vendorsTable

        ConvertTo-ToolkitDashboardSection `
            -Title "Categories" `
            -Subtitle "Findings grouped by classification category." `
            -Content $categoriesTable

        ConvertTo-ToolkitDashboardSection `
            -Title "Recommendations" `
            -Subtitle "Recommended treatment of discovered inventory." `
            -Content $recommendationsTable

        ConvertTo-ToolkitDashboardSection `
            -Title "Risk Levels" `
            -Subtitle "Risk classifications associated with recommendations." `
            -Content $risksTable
    )

    $encodedComputer = ConvertTo-ToolkitHtmlEncoded `
        -Value $ComputerName

    $encodedVersion = ConvertTo-ToolkitHtmlEncoded `
        -Value $ToolkitVersion

    $encodedReportPath = ConvertTo-ToolkitHtmlEncoded `
        -Value $Summary.ReportPath

    return @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WindowsToolkit Inventory Dashboard</title>
<style>
:root {
    color-scheme: light dark;
    --page: #0b1020;
    --panel: #141b2d;
    --panel-alt: #1a2338;
    --text: #e8edf7;
    --muted: #9da9bf;
    --border: #2a3650;
    --accent: #58a6ff;
    --success: #3fb950;
    --warning: #d29922;
    --danger: #f85149;
    --shadow: 0 12px 30px rgba(0, 0, 0, .22);
}

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    background:
        radial-gradient(circle at top right, #162748 0, transparent 35%),
        var(--page);
    color: var(--text);
    font-family:
        Inter,
        "Segoe UI",
        system-ui,
        -apple-system,
        sans-serif;
    line-height: 1.5;
}

.container {
    width: min(1400px, calc(100% - 32px));
    margin: 0 auto;
    padding: 36px 0 60px;
}

.hero {
    padding: 30px;
    border: 1px solid var(--border);
    border-radius: 18px;
    background:
        linear-gradient(
            135deg,
            rgba(88, 166, 255, .15),
            rgba(63, 185, 80, .06)
        ),
        var(--panel);
    box-shadow: var(--shadow);
}

.eyebrow {
    margin: 0 0 8px;
    color: var(--accent);
    font-size: .82rem;
    font-weight: 700;
    letter-spacing: .12em;
    text-transform: uppercase;
}

h1 {
    margin: 0;
    font-size: clamp(2rem, 5vw, 3.2rem);
    letter-spacing: -.04em;
}

.hero-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 10px 24px;
    margin-top: 18px;
    color: var(--muted);
}

.cards {
    display: grid;
    grid-template-columns:
        repeat(auto-fit, minmax(210px, 1fr));
    gap: 16px;
    margin: 22px 0;
}

.card {
    padding: 22px;
    border: 1px solid var(--border);
    border-radius: 16px;
    background: var(--panel);
    box-shadow: var(--shadow);
}

.card-label {
    color: var(--muted);
    font-size: .82rem;
    font-weight: 700;
    letter-spacing: .08em;
    text-transform: uppercase;
}

.card-value {
    margin-top: 8px;
    font-size: 2rem;
    font-weight: 750;
}

.dashboard-grid {
    display: grid;
    grid-template-columns:
        repeat(auto-fit, minmax(420px, 1fr));
    gap: 18px;
}

.panel {
    min-width: 0;
    overflow: hidden;
    border: 1px solid var(--border);
    border-radius: 16px;
    background: var(--panel);
    box-shadow: var(--shadow);
}

.section-header {
    padding: 20px 22px 12px;
}

.section-header h2 {
    margin: 0;
    font-size: 1.2rem;
}

.section-subtitle {
    margin: 5px 0 0;
    color: var(--muted);
    font-size: .9rem;
}

.table-wrap {
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
}

th,
td {
    padding: 12px 22px;
    border-top: 1px solid var(--border);
    text-align: left;
    vertical-align: top;
}

th {
    color: var(--muted);
    background: var(--panel-alt);
    font-size: .76rem;
    letter-spacing: .08em;
    text-transform: uppercase;
}

td:last-child,
th:last-child {
    text-align: right;
}

tbody tr:hover {
    background: rgba(88, 166, 255, .055);
}

.empty-state {
    padding: 24px 22px;
    border-top: 1px solid var(--border);
    color: var(--muted);
}

.footer {
    margin-top: 24px;
    padding: 20px 4px;
    color: var(--muted);
    font-size: .84rem;
    text-align: center;
    overflow-wrap: anywhere;
}

@media (max-width: 720px) {
    .container {
        width: min(100% - 18px, 1400px);
        padding-top: 12px;
    }

    .hero {
        padding: 22px;
    }

    .dashboard-grid {
        grid-template-columns: 1fr;
    }

    th,
    td {
        padding: 10px 14px;
    }
}

@media print {
    :root {
        --page: #ffffff;
        --panel: #ffffff;
        --panel-alt: #f3f5f8;
        --text: #111827;
        --muted: #4b5563;
        --border: #d1d5db;
        --shadow: none;
    }

    body {
        background: #ffffff;
    }

    .panel,
    .card,
    .hero {
        break-inside: avoid;
    }
}
</style>
</head>
<body>
<main class="container">
    <header class="hero">
        <p class="eyebrow">WindowsToolkit v$encodedVersion</p>
        <h1>Inventory Dashboard</h1>

        <div class="hero-meta">
            <span><strong>Computer:</strong> $encodedComputer</span>
            <span><strong>Generated:</strong> $generatedAt</span>
        </div>
    </header>

    <section class="cards">
        <article class="card">
            <div class="card-label">Analyzer Reports</div>
            <div class="card-value">$($Summary.ReportCount)</div>
        </article>

        <article class="card">
            <div class="card-label">Inventory Items</div>
            <div class="card-value">$($Summary.TotalItems)</div>
        </article>

        <article class="card">
            <div class="card-label">Known Vendors</div>
            <div class="card-value">$(@($Summary.Vendors).Count)</div>
        </article>

        <article class="card">
            <div class="card-label">Categories</div>
            <div class="card-value">$(@($Summary.Categories).Count)</div>
        </article>
    </section>

    <div class="dashboard-grid">
        $($sections -join [Environment]::NewLine)
    </div>

    <footer class="footer">
        Report directory: $encodedReportPath
    </footer>
</main>
</body>
</html>
"@
}

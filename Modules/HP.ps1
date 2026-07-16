$Root = Split-Path -Parent $PSScriptRoot

Import-Module "$Root\Core\Logger.psm1" -Force
Import-Module "$Root\Core\Console.psm1" -Force
Import-Module "$Root\Core\Reporting.psm1" -Force
Import-Module "$Root\Core\Models.psm1" -Force
Import-Module "$Root\Core\Discovery.psm1" -Force
Import-Module "$Root\Core\Recommendation.psm1" -Force

Write-Section "HP Analyzer"

$findings = @()

function Add-HPFinding {
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [Parameter(Mandatory)]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Source,

        [string]$Version = "",
        [string]$State = "",
        [string]$ServiceName = "",
        [string]$ServiceDisplayName = "",
        [string]$StartupType = "",
        [string]$Dependencies = "",
        [string]$RecoveryConfiguration = ""
    )

    $vendorContext = Get-ToolkitRecommendation `
        -Text $Text `
        -Type "general"

    if ($vendorContext.Vendor -ne "HP") {
        return
    }

    $recommendation = Get-ToolkitRecommendation `
        -Text $Text `
        -Type "hp"
    $resolvedSource = Resolve-ToolkitFindingSource -Source $Source

    $script:findings += New-ToolkitFinding `
        -Name $Name `
        -Type $Type `
        -Vendor $recommendation.Vendor `
        -Category $recommendation.Category `
        -Recommendation $recommendation.Recommendation `
        -Risk $recommendation.Risk `
        -Reason $recommendation.Reason `
        -Source $resolvedSource `
        -Version $Version `
        -State $State `
        -ServiceName $ServiceName `
        -ServiceDisplayName $ServiceDisplayName `
        -StartupType $StartupType `
        -Dependencies $Dependencies `
        -RecoveryConfiguration $RecoveryConfiguration
}

foreach ($service in Get-ToolkitServices) {
    Add-HPFinding `
        -Item $service `
        -Type "HP Service" `
        -Text "$($service.Name) $($service.DisplayName) $($service.PathName)" `
        -Name $service.DisplayName `
        -Source "Windows Service" `
        -State $service.State `
        -ServiceName $service.Name `
        -ServiceDisplayName $service.DisplayName `
        -StartupType $service.StartupType `
        -Dependencies $service.Dependencies `
        -RecoveryConfiguration $service.RecoveryConfiguration
}

foreach ($software in Get-ToolkitInstalledSoftware) {
    if ([string]::IsNullOrWhiteSpace([string]$software.DisplayName)) {
        continue
    }

    $source = if ($software.PSPath) {
        $software.PSPath
    }
    elseif ($software.InstallLocation) {
        $software.InstallLocation
    }
    else {
        "Windows Uninstall Registry"
    }

    Add-HPFinding `
        -Item $software `
        -Type "HP Software" `
        -Text "$($software.DisplayName) $($software.Publisher)" `
        -Name $software.DisplayName `
        -Source $source `
        -Version $software.DisplayVersion `
        -State "Installed"
}

foreach ($driver in Get-ToolkitDrivers) {
    $name = if ($driver.DeviceName) {
        $driver.DeviceName
    }
    else {
        "Unknown HP Driver"
    }

    Add-HPFinding `
        -Item $driver `
        -Type "HP Driver" `
        -Text "$($driver.DeviceName) $($driver.Manufacturer) $($driver.DriverProviderName) $($driver.InfName)" `
        -Name $name `
        -Source $driver.InfName `
        -Version $driver.DriverVersion `
        -State "Installed"
}

foreach ($task in Get-ToolkitScheduledTasks) {
    $name = "$($task.TaskPath)$($task.TaskName)"

    Add-HPFinding `
        -Item $task `
        -Type "HP Scheduled Task" `
        -Text "$name $($task.Author)" `
        -Name $name `
        -Source "Task Scheduler" `
        -State $task.State
}

$reportPath = Save-CsvReport `
    -Name "HP_Analyzer" `
    -Data $findings

Write-Success "HP Analyzer complete."
Write-Host "HP items found: $($findings.Count)"
Write-Host "Report saved to: $reportPath"

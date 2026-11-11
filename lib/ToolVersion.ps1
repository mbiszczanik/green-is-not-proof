function Get-BicepCliVersion {
    <#
    .SYNOPSIS
    Returns the Bicep CLI version (for example 0.38.5), or '' when no Bicep CLI answers.
    .DESCRIPTION
    Asks -BicepPath when given, else `bicep` on the path, else `az bicep`: the order demo 6 uses for the linter.
    .EXAMPLE
    Get-BicepCliVersion
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$BicepPath)
    try {
        $out = @()
        if ($BicepPath) { $out = @(& $BicepPath --version 2>&1) }
        elseif (Get-Command bicep -ErrorAction SilentlyContinue) { $out = @(& bicep --version 2>&1) }
        elseif (Get-Command az -ErrorAction SilentlyContinue) { $out = @(& az bicep version 2>&1) }
        # Anchored on the product name: az can also print the version of a newer release it found.
        if (($out -join "`n") -match 'Bicep CLI version (\d+\.\d+\.\d+)') { return $Matches[1] }
        return ''
    }
    catch { return '' }
}

function Get-DemoToolVersion {
    <#
    .SYNOPSIS
    Returns the version of one tool as text, or '' when it is not found.
    .DESCRIPTION
    'PowerShell' is the running session, 'Bicep CLI' is asked through Get-BicepCliVersion. Any other name is a
    module: the loaded version, else the highest installed one, which is the one an import without a version takes.
    .EXAMPLE
    Get-DemoToolVersion -Name Pester
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Name, [string]$BicepPath)
    if ($Name -eq 'PowerShell') { return $PSVersionTable.PSVersion.ToString() }
    if ($Name -eq 'Bicep CLI') { return Get-BicepCliVersion -BicepPath $BicepPath }
    $module = Get-Module -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) { $module = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1 }
    if ($module) { return $module.Version.ToString() }
    ''
}

function Format-DemoToolVersion {
    <#
    .SYNOPSIS
    Returns the lines a demo prints about its tools: the versions, one warning per difference, and what was not compared.
    .DESCRIPTION
    Each tool is an object with Name, Actual (the version found, '' when missing) and Observed (the version the
    demo's result was recorded with, '' when none is recorded). A missing tool with a recorded version warns too.
    A tool without a recorded version is named as not compared, so a quiet run is not read as a match.
    .EXAMPLE
    Format-DemoToolVersion -Tool ([pscustomobject]@{ Name = 'PowerShell'; Actual = '7.6.9'; Observed = '7.6.9' })
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Tool)
    $shown = @($Tool | ForEach-Object { if ($_.Actual) { "$($_.Name) $($_.Actual)" } else { "$($_.Name) (not found)" } })
    $lines = @("Tool versions: $($shown -join '; ')")
    foreach ($t in $Tool) {
        if (-not $t.Observed) { continue }
        if (-not $t.Actual) { $lines += "WARNING: $($t.Name) was not found; this demo's result was observed with $($t.Name) $($t.Observed)." }
        elseif ($t.Actual -ne $t.Observed) { $lines += "WARNING: $($t.Name) is $($t.Actual); this demo's result was observed with $($t.Name) $($t.Observed)." }
    }
    $unknown = @($Tool | Where-Object { -not $_.Observed } | ForEach-Object { $_.Name })
    if ($unknown.Count -gt 0) { $lines += "Not compared, no observed version is recorded: $($unknown -join ', ')" }
    $lines
}

function Write-DemoToolVersion {
    <#
    .SYNOPSIS
    Prints the versions of the tools one demo depends on, and a warning for each that differs from the observed one.
    .DESCRIPTION
    Reads the demo's tools and their observed versions from config/demo-tools.psd1. It reports and never stops the
    demo: if the versions cannot be read, it prints a warning saying so.
    .EXAMPLE
    Write-DemoToolVersion -Demo Demo4
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Demo,
        [string]$BicepPath,
        [string]$ConfigPath = (Join-Path $PSScriptRoot '../config/demo-tools.psd1')
    )
    try {
        $all = Import-PowerShellDataFile -LiteralPath $ConfigPath -ErrorAction Stop
        if (-not $all.ContainsKey($Demo)) { throw "no entry '$Demo' in the tool list" }
        $tools = @(foreach ($entry in $all[$Demo]) {
                [pscustomobject]@{
                    Name     = [string]$entry['Name']
                    Observed = [string]$entry['Observed']
                    Actual   = [string](Get-DemoToolVersion -Name $entry['Name'] -BicepPath $BicepPath)
                }
            })
        Format-DemoToolVersion -Tool $tools | ForEach-Object { Write-Host $_ }
    }
    catch {
        # The folder is cut out so a recording shows no user name.
        $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
        Write-Host "WARNING: tool versions could not be read: $($_.Exception.Message.Replace($root, '.'))"
    }
    Write-Host ''
}

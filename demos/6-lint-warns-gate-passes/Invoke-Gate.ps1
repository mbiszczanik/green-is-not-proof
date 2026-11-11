<#
.SYNOPSIS
Demo 6: lints a Bicep template and applies one of two gates to the result. Needs no Azure access.
.DESCRIPTION
Bare reads only the process exit code of the linter. Fixed also fails when the output holds a Warning or
Error diagnostic. Prints the linter output, the process exit code, how many diagnostic lines the output held
and the gate's verdict; if the Bare gate passes while the output shows a diagnostic, it says so. Exits 0 when
the chosen gate passes and 1 when it fails or when no linter can be run. Local paths are printed as '.'.
.EXAMPLE
./demos/6-lint-warns-gate-passes/Invoke-Gate.ps1 -Gate Bare -Template Sample
.EXAMPLE
./demos/6-lint-warns-gate-passes/Invoke-Gate.ps1 -Gate Fixed -Template Sample
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Bare', 'Fixed')][string]$Gate,
    [ValidateSet('Sample', 'Clean')][string]$Template = 'Sample'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../../lib/ToolVersion.ps1

function Get-LintFinding {
    <#
    .SYNOPSIS
    Returns the lines of linter output that are Warning or Error diagnostics.
    .EXAMPLE
    Get-LintFinding -Line $output
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([string[]]$Line = @())
    # Case-sensitive on purpose: the diagnostic reads "path(2,7) : Warning rule: message".
    @($Line | Where-Object { $_ -cmatch ': (Warning|Error) ' })
}

function Test-LintGate {
    <#
    .SYNOPSIS
    True when the gate passes. Bare reads the exit code only; Fixed also fails on any Warning or Error line.
    .EXAMPLE
    Test-LintGate -Gate Fixed -ExitCode 0 -Line $output
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][ValidateSet('Bare', 'Fixed')][string]$Gate,
        [Parameter(Mandatory)][int]$ExitCode,
        [string[]]$Line = @()
    )
    if ($ExitCode -ne 0) { return $false }
    if ($Gate -eq 'Fixed' -and @(Get-LintFinding -Line $Line).Count -gt 0) { return $false }
    $true
}

function Invoke-BicepLint {
    <#
    .SYNOPSIS
    Runs the Bicep linter in a child process and returns its exit code and output lines.
    .EXAMPLE
    $r = Invoke-BicepLint -Path ./Sample.bicep
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][string]$Path)
    if (Get-Command bicep -ErrorAction SilentlyContinue) { $lines = @(& bicep lint $Path 2>&1 | ForEach-Object { "$_" }) }
    elseif (Get-Command az -ErrorAction SilentlyContinue) { $lines = @(& az bicep lint --file $Path 2>&1 | ForEach-Object { "$_" }) }
    else { throw 'Neither bicep nor az is installed: the linter cannot run, so no gate result exists.' }
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Line = $lines }
}

function Hide-LocalPath {
    <#
    .SYNOPSIS
    Replaces the folder of this demo, in both slash styles, with '.' so a recording shows no user name.
    .EXAMPLE
    Hide-LocalPath -Text $line -Folder $PSScriptRoot
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Text, [Parameter(Mandatory)][string]$Folder)
    $full = [IO.Path]::GetFullPath($Folder).TrimEnd('\', '/')
    $text = $Text -replace [regex]::Escape($full), '.'
    $text -replace [regex]::Escape($full.Replace('\', '/')), '.'
}

if ($MyInvocation.InvocationName -ne '.') {
    Write-DemoToolVersion -Demo Demo6
    $path = Join-Path $PSScriptRoot "$Template.bicep"
    try { $r = Invoke-BicepLint -Path $path }
    catch { Write-Host $_.Exception.Message; exit 1 }
    $r.Line | Where-Object { $_.Trim() } | ForEach-Object { Write-Host (Hide-LocalPath -Text $_ -Folder $PSScriptRoot) }
    $findings = @(Get-LintFinding -Line $r.Line).Count
    $pass = Test-LintGate -Gate $Gate -ExitCode $r.ExitCode -Line $r.Line
    Write-Host ''
    Write-Host "Process exit code: $($r.ExitCode)"
    Write-Host "Warning or Error lines in the output: $findings"
    Write-Host "$Gate gate: $(if ($pass) { 'PASS' } else { 'FAIL' })"
    if ($Gate -eq 'Bare' -and $pass -and $findings -gt 0) { Write-Host 'The gate would PASS although the output shows a diagnostic.' }
    if (-not $pass) { exit 1 }
}

<#
.SYNOPSIS
Demo 7: runs PSRule for Azure on a Bicep file and applies one of two gates to the result. Needs no Azure access.
.DESCRIPTION
Bare reads only the process exit code of Assert-PSRule. Fixed also fails when PSRule printed no summary line or
evaluated zero rules. -Pipeline Misconfigured leaves Bicep expansion off, so the insecure template is never
evaluated; Configured turns it on. Prints the PSRule warnings, errors and failed rules, the summary line, the
process exit code and the verdict. Exits 0 when the chosen gate passes and 1 when it fails or the rules cannot run.
Local paths are printed as '.'. Needs PowerShell 7, PSRule and PSRule.Rules.Azure, and the Bicep CLI for Configured.
.EXAMPLE
./demos/7-unprocessed-object-passes/Invoke-Gate.ps1 -Gate Bare -Pipeline Misconfigured
.EXAMPLE
./demos/7-unprocessed-object-passes/Invoke-Gate.ps1 -Gate Fixed -Pipeline Misconfigured
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Bare', 'Fixed')][string]$Gate,
    [ValidateSet('Misconfigured', 'Configured')][string]$Pipeline = 'Misconfigured'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../../lib/ToolVersion.ps1

function Get-PSRuleSummary {
    <#
    .SYNOPSIS
    Returns the counts of the 'Rules processed: N, failed: N, errored: N' line, or $null when there is none.
    .EXAMPLE
    Get-PSRuleSummary -Line $output
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([string[]]$Line = @())
    foreach ($l in $Line) {
        if ($l -cmatch 'Rules processed: (\d+), failed: (\d+), errored: (\d+)') {
            return [pscustomobject]@{ Processed = [int]$Matches[1]; Failed = [int]$Matches[2]; Errored = [int]$Matches[3] }
        }
    }
    $null
}

function Test-PSRuleGate {
    <#
    .SYNOPSIS
    True when the gate passes. Bare reads the exit code only; Fixed also needs a summary with at least one rule processed.
    .EXAMPLE
    Test-PSRuleGate -Gate Fixed -ExitCode 0 -Line $output
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][ValidateSet('Bare', 'Fixed')][string]$Gate,
        [Parameter(Mandatory)][int]$ExitCode,
        [string[]]$Line = @()
    )
    if ($ExitCode -ne 0) { return $false }
    if ($Gate -eq 'Fixed') {
        $s = Get-PSRuleSummary -Line $Line
        if ($null -eq $s -or $s.Processed -lt 1 -or $s.Errored -gt 0) { return $false }
    }
    $true
}

function Invoke-PSRuleProcess {
    <#
    .SYNOPSIS
    Runs the PSRule child in its own process and returns its exit code and output lines.
    .EXAMPLE
    $r = Invoke-PSRuleProcess -Path ./Storage.bicep -ExpandBicep On
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][ValidateSet('On', 'Off')][string]$ExpandBicep)
    $pwsh = (Get-Process -Id $PID).Path
    $child = Join-Path $PSScriptRoot 'Invoke-PSRuleChild.ps1'
    $lines = @(& $pwsh -NoProfile -File $child -Path $Path -ExpandBicep $ExpandBicep 2>&1 | ForEach-Object { "$_" })
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
    # PSRule compiles with the Bicep CLI this variable names when it is set, else with the one on the path.
    Write-DemoToolVersion -Demo Demo7 -BicepPath $env:PSRULE_AZURE_BICEP_PATH
    $path = Join-Path $PSScriptRoot 'Storage.bicep'
    $r = Invoke-PSRuleProcess -Path $path -ExpandBicep $(if ($Pipeline -eq 'Configured') { 'On' } else { 'Off' })
    # PSRule prints a banner and the help of every failed rule; keep the lines that carry the result.
    $r.Line | Where-Object { $_ -match '^\s*\[(WARN|ERROR|FAIL)\]|Rules processed:|not installed' } |
        ForEach-Object { Write-Host (Hide-LocalPath -Text $_ -Folder $PSScriptRoot) }
    $summary = Get-PSRuleSummary -Line $r.Line
    $pass = Test-PSRuleGate -Gate $Gate -ExitCode $r.ExitCode -Line $r.Line
    Write-Host ''
    Write-Host "Process exit code: $($r.ExitCode)"
    Write-Host "Rules evaluated: $(if ($summary) { $summary.Processed } else { 'no summary printed' })"
    Write-Host "$Gate gate: $(if ($pass) { 'PASS' } else { 'FAIL' })"
    if ($Gate -eq 'Bare' -and $pass -and ($null -eq $summary -or $summary.Processed -lt 1)) {
        Write-Host 'The gate would PASS although no rule was evaluated.'
    }
    if (-not $pass) { exit 1 }
}

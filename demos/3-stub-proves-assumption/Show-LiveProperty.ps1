<#
.SYNOPSIS
Demo 3: reads the run's Log Analytics workspace live and prints the property the strict health check demands.
.DESCRIPTION
Needs a run from scripts/Start-DemoRun.ps1 (-RunId, else out/run.json). Prints the masked property value
(or "(empty)"), then the Strict and Lenient verdicts. It reports; it is not a gate, so it exits 0 on a read.
.EXAMPLE
./demos/3-stub-proves-assumption/Show-LiveProperty.ps1
#>
[CmdletBinding()]
param(
    [string]$RunId,
    [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../../lib/RunContext.ps1
. $PSScriptRoot/../../lib/Mask.ps1
. $PSScriptRoot/Test-WorkspaceHealth.ps1

function Invoke-ShowLiveProperty {
    <#
    .SYNOPSIS
    Prints the live property and both verdicts; returns 0 on a successful read or 1 on any failure.
    .EXAMPLE
    $code = Invoke-ShowLiveProperty -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string]$RunId,
        [Parameter(Mandatory)][string]$OutDir
    )
    $sub = ''
    try {
        $ctx = Get-AzContext
        if (-not $ctx) { Write-Host 'Run Connect-AzAccount first'; return 1 }
        $sub = $ctx.Subscription.Id

        $runFile = Join-Path $OutDir 'run.json'
        if (-not (Test-Path $runFile) -and -not $RunId) { throw 'No -RunId given and no run.json found' }
        $run = if (Test-Path $runFile) { Get-Content $runFile -Raw | ConvertFrom-Json } else { $null }
        if (-not $RunId) { $RunId = $run.RunId }
        if ($RunId -notmatch '^\d{12}$') { throw "RunId must be 12 digits (yyyyMMddHHmm), got '$RunId'" }
        if ($run -and $run.RunId -ne $RunId) { throw "run.json holds run $($run.RunId), not $RunId" }
        Assert-DemoRunSubscription -Run $run -Current $sub
        $rg = Get-DemoResourceGroupName -RunId $RunId

        $ws = Get-AzOperationalInsightsWorkspace -ResourceGroupName $rg -Name "log-gnp-$RunId"
        $name = Get-HealthPropertyName
        $value = '(empty)'
        if (-not (Test-HealthPropertyEmpty -Workspace $ws)) { $value = @($ws.PSObject.Properties[$name].Value | Where-Object { "$_".Trim() }) -join ', ' }
        $lines = @(
            "${name}: $value"
            "Strict health: $(Test-WorkspaceHealth -Workspace $ws -Mode Strict)"
            "Lenient health: $(Test-WorkspaceHealth -Workspace $ws -Mode Lenient)"
        )
        Write-Host (ConvertTo-MaskedText -Text ($lines -join [Environment]::NewLine) -SubscriptionId $sub)
        return 0
    }
    catch {
        Write-Host (ConvertTo-MaskedText -Text "Show-LiveProperty failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../../out' }
    $code = Invoke-ShowLiveProperty -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}

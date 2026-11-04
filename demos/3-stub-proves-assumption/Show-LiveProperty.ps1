<#
.SYNOPSIS
Demo 3: reads the run's Log Analytics workspace live and prints the property the strict health check demands.
.DESCRIPTION
Needs a run from scripts/Start-DemoRun.ps1 (-RunId, else out/run.json). Prints the masked property value
(or "(empty)"), the ProvisioningState (or "(missing)") and the verdict. It reports; it is not a gate, so it
exits 0 on a read. It describes one read of one workspace at one moment, nothing more.
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
    Prints the live property, the state and the verdict; returns 0 on a successful read or 1 on any failure.
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

        if (-not $RunId) {
            $latest = Read-DemoRun -OutDir $OutDir
            if (-not $latest) { throw 'No -RunId given and no run.json found' }
            $RunId = $latest.RunId
        }
        if ($RunId -notmatch '^\d{12}$') { throw "RunId must be 12 digits (yyyyMMddHHmm), got '$RunId'" }
        # A run.json from another run is no record of this one; the configured demo subscription pins it, as in teardown.
        $run = Read-DemoRun -OutDir $OutDir -RunId $RunId
        Assert-DemoRunSubscription -Run $run -Current $sub
        $rg = Get-DemoResourceGroupName -RunId $RunId

        $ws = Get-AzOperationalInsightsWorkspace -ResourceGroupName $rg -Name "log-gnp-$RunId"
        $name = Get-HealthPropertyName
        $value = '(empty)'
        if (-not (Test-HealthPropertyEmpty -Workspace $ws)) { $value = @($ws.PSObject.Properties[$name].Value | Where-Object { "$_".Trim() }) -join ', ' }
        $stateProp = $ws.PSObject.Properties['ProvisioningState']
        $state = if ($stateProp -and "$($stateProp.Value)".Trim()) { [string]$stateProp.Value } else { '(missing)' }
        $lines = @(
            "${name}: $value"
            "ProvisioningState: $state"
            "Strict health: $(Test-WorkspaceHealth -Workspace $ws)"
            'One read of this workspace, in this configuration, at this moment.'
        )
        Write-Host (ConvertTo-SafeText -Text ($lines -join [Environment]::NewLine) -SubscriptionId $sub)
        return 0
    }
    catch {
        Write-Host (ConvertTo-SafeText -Text "Show-LiveProperty failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../../out' }
    $code = Invoke-ShowLiveProperty -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}

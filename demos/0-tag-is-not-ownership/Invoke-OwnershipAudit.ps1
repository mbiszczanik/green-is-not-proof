<#
.SYNOPSIS
Demo 0, the red: compares the resource group's inventory with the names the code declares.
.DESCRIPTION
Inventory is everything in the run's resource group, tagged or not. Expected names come from
config/demo-manifest.psd1. Anything else is listed under 'Not declared in code:' and the exit code is 1.
RunId comes from -RunId or out/run.json.
.EXAMPLE
./demos/0-tag-is-not-ownership/Invoke-OwnershipAudit.ps1
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
. $PSScriptRoot/../../lib/Ownership.ps1

function Invoke-OwnershipAudit {
    <#
    .SYNOPSIS
    Prints undeclared resources and returns 1, or prints the OK line and returns 0.
    .EXAMPLE
    $code = Invoke-OwnershipAudit -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([string]$RunId, [Parameter(Mandatory)][string]$OutDir)
    $sub = ''
    try {
        $ctx = Get-AzContext
        if (-not $ctx) { Write-Host 'Run Connect-AzAccount first'; return 1 }
        $sub = $ctx.Subscription.Id
        $RunId = Resolve-AuditRunId -RunId $RunId -OutDir $OutDir
        Assert-DemoRunSubscription -Run (Read-DemoRun -OutDir $OutDir -RunId $RunId) -Current $sub
        $rg = Get-DemoResourceGroupName -RunId $RunId
        $manifest = Import-PowerShellDataFile $PSScriptRoot/../../config/demo-manifest.psd1
        $expected = @($manifest.Names | ForEach-Object { $_ -replace '\{runId\}', $RunId })
        $inventory = @(Get-AzResource -ResourceGroupName $rg)
        $flagged = @(Find-UnownedResource -Inventory $inventory -ExpectedName $expected)
        if ($flagged.Count -gt 0) {
            Write-Host 'Not declared in code:'
            Write-Host ($flagged | Write-DemoOutput -SubscriptionId $sub)
            return 1
        }
        Write-Host "All $($inventory.Count) resources are declared in code: OK"
        return 0
    }
    catch {
        Write-Host (ConvertTo-SafeText -Text "Ownership audit failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../../out' }
    $code = Invoke-OwnershipAudit -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}

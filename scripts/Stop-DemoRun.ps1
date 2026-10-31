<#
.SYNOPSIS
Tears down one demo run and proves nothing tagged with its run id remains.
.DESCRIPTION
Removes diagnostic settings on every resource in the run's group (and on the four storage sub-services),
deletes the group, then queries resources tagged runId=<id> and exits 1 if any remain. A diagnostic
setting is a separate resource that deleting the group may not cascade to. The run id comes from -RunId
or out/run.json; run.json is removed only after a clean teardown of the same run.
.EXAMPLE
./scripts/Stop-DemoRun.ps1 -RunId 202611181805
#>
[CmdletBinding()]
param(
    [string]$RunId,
    [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../lib/RunContext.ps1
. $PSScriptRoot/../lib/Mask.ps1
. $PSScriptRoot/../lib/DiagnosticSettings.ps1

function Test-DemoResourceGroup {
    <#
    .SYNOPSIS
    Returns $true if the resource group exists, $false only on a not-found error; any other error throws.
    .EXAMPLE
    Test-DemoResourceGroup -Name rg-gnp-202611181805
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Name)
    try { return [bool](Get-AzResourceGroup -Name $Name -ErrorAction Stop) }
    catch {
        if ($_.Exception.Message -match "could not be found|ResourceGroupNotFound|NotFound") { return $false }
        throw
    }
}

function Invoke-StopDemoRun {
    <#
    .SYNOPSIS
    Runs the teardown and returns 0 on success or 1 on any failure or leftover resource.
    .EXAMPLE
    $code = Invoke-StopDemoRun -RunId '202611181805' -OutDir ./out
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
        if (-not $RunId) {
            if (-not (Test-Path $runFile)) { throw 'No -RunId given and no run.json found' }
            $RunId = (Get-Content $runFile -Raw | ConvertFrom-Json).RunId
        }
        if ($RunId -notmatch '^\d{12}$') { throw "RunId must be 12 digits (yyyyMMddHHmm), got '$RunId'" }
        $rg = Get-DemoResourceGroupName -RunId $RunId

        if (Test-DemoResourceGroup -Name $rg) {
            $removed = 0
            foreach ($res in @(Get-AzResource -ResourceGroupName $rg)) {
                $ids = @($res.ResourceId)
                if ($res.ResourceType -eq 'Microsoft.Storage/storageAccounts') {
                    $ids += 'blob', 'file', 'queue', 'table' | ForEach-Object { "$($res.ResourceId)/${_}Services/default" }
                }
                foreach ($id in $ids) { $removed += Remove-DemoDiagnosticSetting -ResourceId $id -SubscriptionId $sub }
            }
            Write-Host "Removed $removed diagnostic setting(s)"
            $deleted = Remove-AzResourceGroup -Name $rg -Force
            if ($deleted -is [bool] -and -not $deleted) { throw "Remove-AzResourceGroup returned false for $rg" }
            Write-Host "Deleted resource group $rg"
        }
        else {
            Write-Host "Resource group $rg not found, skipping deletion"
        }

        if (Test-DemoResourceGroup -Name $rg) { Write-Host "Resource group $rg still exists"; return 1 }
        $left = @(Get-AzResource -TagName runId -TagValue $RunId)
        if ($left.Count -gt 0) {
            Write-Host "Resources tagged runId=$RunId still exist:"
            Write-Host (($left | Select-Object ResourceId, Name | Write-DemoOutput -SubscriptionId $sub))
            return 1
        }
        Write-Host "Nothing tagged runId=$RunId remains"

        if (Test-Path $runFile) {
            $saved = (Get-Content $runFile -Raw | ConvertFrom-Json).RunId
            if ($saved -eq $RunId) { Remove-Item $runFile -Force }
        }
        return 0
    }
    catch {
        Write-Host (ConvertTo-MaskedText -Text "Stop-DemoRun failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../out' }
    $code = Invoke-StopDemoRun -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { $Host.SetShouldExit(1); exit 1 }
}

<#
.SYNOPSIS
Tears down one demo run and proves nothing tagged with its run id remains.
.DESCRIPTION
Removes diagnostic settings on every resource in the run's group (and on the four storage sub-services),
deletes the group, then queries resources tagged runId=<id> (up to 6 times, 10 s apart) and exits 1 if any remain. A diagnostic
setting is a separate resource that deleting the group may not cascade to. The run id comes from -RunId
or out/run.json; run.json is removed only after a clean teardown of the same run. The current subscription must
equal the one in run.json (or the configured demo subscription when only -RunId is given). If the run's storage
account is missing from the group, it stops before deleting anything: demo 1's diagnostic setting may survive.
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
        [Parameter(Mandatory)][string]$OutDir,
        [int]$PollDelaySeconds = 10
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
        $run = Read-DemoRun -OutDir $OutDir -RunId $RunId
        Assert-DemoRunSubscription -Run $run -Current $sub

        if (Test-DemoResourceGroup -Name $rg) {
            $inventory = @(Get-AzResource -ResourceGroupName $rg)
            if ($run -and $run.PSObject.Properties['StorageAccountName'] -and $run.StorageAccountName) {
                $present = @($inventory | Where-Object { $_.ResourceType -eq 'Microsoft.Storage/storageAccounts' } | ForEach-Object { [string]$_.Name })
                if ($run.StorageAccountName -notin $present) {
                    Write-Host "Storage $($run.StorageAccountName) from this run is missing; its diagnostic setting may survive. Run demo 1 -Step Recreate, then -Step Clean, then teardown again."
                    return 1
                }
            }
            $removed = 0
            foreach ($res in $inventory) {
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
        # Tag queries lag behind a delete, so poll before calling anything a leftover.
        for ($i = 1; $i -le 6; $i++) {
            $left = @(Get-AzResource -TagName runId -TagValue $RunId)
            if ($left.Count -eq 0) { break }
            if ($i -lt 6 -and $PollDelaySeconds -gt 0) { Start-Sleep -Seconds $PollDelaySeconds }
        }
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
        Write-Host (ConvertTo-SafeText -Text "Stop-DemoRun failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../out' }
    $code = Invoke-StopDemoRun -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}

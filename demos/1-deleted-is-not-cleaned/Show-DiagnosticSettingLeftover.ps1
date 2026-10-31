<#
.SYNOPSIS
Demo 1: a diagnostic setting survives its storage account's deletion and re-attaches to a recreated account of the same name.
.DESCRIPTION
One step per run, one masked line each, so the speaker advances on stage: Show, Delete, Recreate, List, Clean.
Uses the run's storage account and its diag-to-log setting on the blob service. Needs a run from
scripts/Start-DemoRun.ps1 (-RunId, else out/run.json). Creates nothing beyond the run's own account.
The current subscription must match the run's (run.json) or the configured demo subscription.
.EXAMPLE
./demos/1-deleted-is-not-cleaned/Show-DiagnosticSettingLeftover.ps1 -Step Delete
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Show', 'Delete', 'Recreate', 'List', 'Clean')][string]$Step,
    [string]$RunId,
    [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../../lib/RunContext.ps1
. $PSScriptRoot/../../lib/Mask.ps1
. $PSScriptRoot/../../lib/DiagnosticSettings.ps1

function Invoke-DiagnosticSettingLeftover {
    <#
    .SYNOPSIS
    Runs one demo step and returns 0 on success or 1 on any failure.
    .EXAMPLE
    $code = Invoke-DiagnosticSettingLeftover -Step Show -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][ValidateSet('Show', 'Delete', 'Recreate', 'List', 'Clean')][string]$Step,
        [string]$RunId,
        [Parameter(Mandatory)][string]$OutDir,
        [int]$RetryDelaySeconds = 5
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
        $rg = Get-DemoResourceGroupName -RunId $RunId
        $name = "stgnp$RunId"
        if ($run -and $run.RunId -ne $RunId) { throw "run.json holds run $($run.RunId), not $RunId" }
        Assert-DemoRunSubscription -Run $run -Current $sub
        $blobId = "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$name/blobServices/default"

        $line = switch ($Step) {
            'Show' {
                $names = @(Get-AzDiagnosticSetting -ResourceId $blobId | ForEach-Object Name) -join ', '
                if (-not $names) { $names = 'none' }
                "Storage $name has diagnostic setting(s): $names"
            }
            'Delete' {
                Remove-AzStorageAccount -ResourceGroupName $rg -Name $name -Force
                "Deleted storage account ${name}: OK"
            }
            'Recreate' {
                if (-not ($run -and $run.PSObject.Properties['Location'] -and $run.Location)) { throw 'run.json has no Location for this run' }
                $tag = Get-DemoTag -RunId $RunId
                # Azure can hold a deleted account's name for a short while.
                $maxRetries = 12
                $told = $false
                for ($i = 0; ; $i++) {
                    try {
                        $null = New-AzStorageAccount -ResourceGroupName $rg -Name $name -Location $run.Location -SkuName Standard_LRS -Kind StorageV2 -Tag $tag
                        break
                    }
                    catch {
                        if ($_.Exception.Message -notmatch 'StorageAccountAlreadyTaken|AlreadyExists|already taken|in use') { throw }
                        if ($i -ge $maxRetries) { throw "name $name still held by Azure after $($maxRetries * $RetryDelaySeconds) s, try again shortly" }
                        if (-not $told) { Write-Host 'Name still held by Azure, retrying...'; $told = $true }
                        Start-Sleep -Seconds $RetryDelaySeconds
                    }
                }
                "Recreated storage account $name"
            }
            'List' {
                $names = @(Get-AzDiagnosticSetting -ResourceId $blobId | ForEach-Object Name) -join ', '
                if (-not $names) { $names = 'none' }
                "Diagnostic settings on the NEW account: $names"
            }
            'Clean' {
                $n = Remove-DemoDiagnosticSetting -ResourceId $blobId -SubscriptionId $sub
                "Removed $n diagnostic setting(s)"
            }
        }
        Write-Host (ConvertTo-SafeText -Text $line -SubscriptionId $sub)
        return 0
    }
    catch {
        Write-Host (ConvertTo-SafeText -Text "$Step failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../../out' }
    $code = Invoke-DiagnosticSettingLeftover -Step $Step -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}

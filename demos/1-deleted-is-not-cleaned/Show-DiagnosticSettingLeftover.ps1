<#
.SYNOPSIS
Demo 1: a diagnostic setting survives its storage account's deletion and re-attaches to a recreated account of the same name.
.DESCRIPTION
One step per run, one masked line each, so the speaker advances on stage: Show, Delete, Recreate, List, Clean.
Show and Verify print the tool versions first.
Verify is the preparation check, not a stage step: after Recreate it exits 1 unless diag-to-log is listed on the new account.
Uses the run's storage account and its diag-to-log setting on the blob service. Needs a run from
scripts/Start-DemoRun.ps1 (-RunId, else out/run.json). Creates nothing beyond the run's own account.
The current subscription must match the run's (run.json) or the configured demo subscription.
.EXAMPLE
./demos/1-deleted-is-not-cleaned/Show-DiagnosticSettingLeftover.ps1 -Step Delete
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Show', 'Delete', 'Recreate', 'List', 'Clean', 'Verify')][string]$Step,
    [string]$RunId,
    [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../../lib/RunContext.ps1
. $PSScriptRoot/../../lib/Mask.ps1
. $PSScriptRoot/../../lib/DiagnosticSettings.ps1
. $PSScriptRoot/../../lib/ToolVersion.ps1

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
        [Parameter(Mandatory)][ValidateSet('Show', 'Delete', 'Recreate', 'List', 'Clean', 'Verify')][string]$Step,
        [string]$RunId,
        [Parameter(Mandatory)][string]$OutDir,
        [int]$RetryDelaySeconds = 5
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
        $rg = Get-DemoResourceGroupName -RunId $RunId
        $name = "stgnp$RunId"
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
            'Verify' {
                # Preparation check, run after Recreate and before the stage: an empty or unrelated listing is a failed preparation.
                $names = @(Get-AzDiagnosticSetting -ResourceId $blobId | ForEach-Object Name)
                if ('diag-to-log' -notin $names) {
                    $found = if ($names) { $names -join ', ' } else { 'none' }
                    Write-Host (ConvertTo-SafeText -Text "Demonstration did not reproduce: expected diagnostic setting diag-to-log on the NEW account, found: $found" -SubscriptionId $sub)
                    return 1
                }
                'Demonstration reproduced: diagnostic setting diag-to-log is listed on the NEW account'
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
    # Once per pass through the demo: its first stage step and the preparation check. The other steps keep to one line.
    if ($Step -in 'Show', 'Verify') { Write-DemoToolVersion -Demo Demo1 }
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../../out' }
    $code = Invoke-DiagnosticSettingLeftover -Step $Step -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}

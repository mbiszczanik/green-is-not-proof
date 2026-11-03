<#
.SYNOPSIS
Demo 5, before the talk: gives the run's VM a script extension that is guaranteed to fail, and waits until Azure marks it Failed.
.DESCRIPTION
Needs a run with the VM from scripts/New-RogueResource.ps1 (-RunId, else out/run.json). Adds the Linux CustomScript
extension gnp-failing-script whose command is `exit 1`. The extension resource stays in the group with
ProvisioningState Failed. It costs nothing beyond the VM the run already prices. If the extension does not reach
Failed within the wait, the script says so and exits 1: the demo must not show a pass it did not produce.
The extension is deleted with the group by scripts/Stop-DemoRun.ps1. Run it after demo 0, because the
ownership audit would list the extension too.
.EXAMPLE
./demos/5-exists-is-not-healthy/New-FailedExtension.ps1
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

$script:ExtensionName = 'gnp-failing-script'

function Invoke-NewFailedExtension {
    <#
    .SYNOPSIS
    Adds the failing extension and returns 0 once it is Failed, or 1 on any other outcome.
    .EXAMPLE
    $code = Invoke-NewFailedExtension -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string]$RunId,
        [Parameter(Mandatory)][string]$OutDir,
        [int]$WaitSeconds = 300,
        [int]$PollSeconds = 15
    )
    $sub = ''
    try {
        $ctx = Get-AzContext
        if (-not $ctx) { Write-Host 'Run Connect-AzAccount first'; return 1 }
        $sub = $ctx.Subscription.Id

        $runFile = Join-Path $OutDir 'run.json'
        if (-not (Test-Path $runFile) -and -not $RunId) { throw 'No -RunId given and no run.json found' }
        $run = Read-DemoRun -OutDir $OutDir -RunId $RunId
        if (-not $run) { throw 'No run.json for this run' }
        Assert-DemoRunSubscription -Run $run -Current $sub
        if (-not ($run.PSObject.Properties['RogueVmName'] -and $run.RogueVmName)) { throw 'The run has no VM. Run scripts/New-RogueResource.ps1 first.' }
        $rg = $run.ResourceGroup
        $vm = $run.RogueVmName

        try {
            $null = Set-AzVMExtension -ResourceGroupName $rg -VMName $vm -Location $run.Location -Name $script:ExtensionName `
                -Publisher 'Microsoft.Azure.Extensions' -ExtensionType 'CustomScript' -TypeHandlerVersion '2.1' `
                -Settings @{ commandToExecute = 'exit 1' } -ErrorAction Stop
            Write-Host 'The extension call returned without an error; reading the state back.'
        }
        catch {
            # The failure is the point; what the extension ended up as is read back below.
            Write-Host (ConvertTo-SafeText -Text "The extension call reported an error, as expected: $($_.Exception.Message)" -SubscriptionId $sub)
        }

        $deadline = (Get-Date).AddSeconds($WaitSeconds)
        $state = '(missing)'
        do {
            $ext = Get-AzVMExtension -ResourceGroupName $rg -VMName $vm -Name $script:ExtensionName -ErrorAction SilentlyContinue
            $p = if ($ext) { $ext.PSObject.Properties['ProvisioningState'] } else { $null }
            $state = if ($p -and "$($p.Value)".Trim()) { [string]$p.Value } else { '(missing)' }
            if ($state -in 'Failed', 'Succeeded') { break }
            if ((Get-Date) -lt $deadline -and $PollSeconds -gt 0) { Start-Sleep -Seconds $PollSeconds }
        } while ((Get-Date) -lt $deadline)

        if ($state -eq 'Failed') {
            Write-Host "Extension $($script:ExtensionName) on $vm reached ProvisioningState Failed"
            return 0
        }
        Write-Host (ConvertTo-SafeText -Text "Extension $($script:ExtensionName) did not reach Failed (state: $state). The demo would not show its point." -SubscriptionId $sub)
        return 1
    }
    catch {
        Write-Host (ConvertTo-SafeText -Text "New-FailedExtension failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../../out' }
    $code = Invoke-NewFailedExtension -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}

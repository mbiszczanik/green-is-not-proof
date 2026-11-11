<#
.SYNOPSIS
Demo 5, on stage: reads the failing extension and prints an existence check (passes) and a state check (fails).
.DESCRIPTION
Needs the extension from New-FailedExtension.ps1 (-RunId, else out/run.json). The existence check passes when the
read returns the extension. The state check passes only for ProvisioningState Succeeded; a missing or blank state
never passes. Exits 0 when it shows the point (exists, state Failed). Exits 1 when the extension is missing or its
state is anything other than Failed, saying so instead of showing a pass.
.EXAMPLE
./demos/5-exists-is-not-healthy/Show-ExistenceVsState.ps1
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
. $PSScriptRoot/../../lib/ToolVersion.ps1

$script:ExtensionName = 'gnp-failing-script'

function Get-ExtensionStateText {
    <#
    .SYNOPSIS
    Returns the ProvisioningState text of an extension object, or '(missing)' for no object, no property or a blank value.
    .EXAMPLE
    Get-ExtensionStateText -Extension $ext
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object]$Extension)
    if ($null -eq $Extension) { return '(missing)' }
    $p = $Extension.PSObject.Properties['ProvisioningState']
    if ($p -and "$($p.Value)".Trim()) { return [string]$p.Value }
    '(missing)'
}

function Invoke-ShowExistenceVsState {
    <#
    .SYNOPSIS
    Prints the two checks; returns 0 when the extension exists in state Failed, else 1.
    .EXAMPLE
    $code = Invoke-ShowExistenceVsState -OutDir ./out
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
        $run = Read-DemoRun -OutDir $OutDir -RunId $RunId
        if (-not $run) { throw 'No run.json for this run' }
        Assert-DemoRunSubscription -Run $run -Current $sub
        if (-not ($run.PSObject.Properties['RogueVmName'] -and $run.RogueVmName)) { throw 'The run has no VM. Run scripts/New-RogueResource.ps1 first.' }

        $ext = Get-AzVMExtension -ResourceGroupName $run.ResourceGroup -VMName $run.RogueVmName -Name $script:ExtensionName -ErrorAction SilentlyContinue
        if (-not $ext) {
            Write-Host "Existence check: FAIL (extension $($script:ExtensionName) not found). Run New-FailedExtension.ps1 first."
            return 1
        }
        $state = Get-ExtensionStateText -Extension $ext
        $existence = "Existence check: PASS (extension $($script:ExtensionName) found)"
        $stateLine = if ($state -eq 'Succeeded') { "State check:     PASS (ProvisioningState: $state)" } else { "State check:     FAIL (ProvisioningState: $state)" }
        Write-Host (ConvertTo-SafeText -Text (@($existence, $stateLine, 'One read of this extension, in this configuration, at this moment.') -join [Environment]::NewLine) -SubscriptionId $sub)
        if ($state -ne 'Failed') {
            Write-Host (ConvertTo-SafeText -Text "The state is $state, not Failed: this run does not show that existing is not working." -SubscriptionId $sub)
            return 1
        }
        return 0
    }
    catch {
        Write-Host (ConvertTo-SafeText -Text "Show-ExistenceVsState failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Write-DemoToolVersion -Demo Demo5
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../../out' }
    $code = Invoke-ShowExistenceVsState -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}

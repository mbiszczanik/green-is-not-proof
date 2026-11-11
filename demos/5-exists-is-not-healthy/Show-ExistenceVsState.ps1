<#
.SYNOPSIS
Demo 5, on stage: reads the failing extension and prints an existence check (passes) and a state check (fails).
.DESCRIPTION
Needs the extension from New-FailedExtension.ps1 (-RunId, else out/run.json). The existence check passes when the
read returns the extension. The state check passes only for ProvisioningState Succeeded; a missing or blank state
never passes. Exit code: 0 only when the state check passes; 1 when it fails (any state but Succeeded), when the
extension is missing, or when the read could not run (the output then says "The check did not run").
With -ExpectFailed (the on-stage run) the demonstration is the assertion: 0 only when the extension exists in state
Failed, 1 for any other state or when the check did not run.
.PARAMETER ExpectFailed
Treat state Failed as the expected result of the demo and exit 0 for it.
.EXAMPLE
./demos/5-exists-is-not-healthy/Show-ExistenceVsState.ps1 -ExpectFailed
#>
[CmdletBinding()]
param(
    [string]$RunId,
    [string]$OutDir,
    [switch]$ExpectFailed
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../../lib/RunContext.ps1
. $PSScriptRoot/../../lib/Mask.ps1

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

function Test-ExtensionNotFound {
    <#
    .SYNOPSIS
    Returns $true only for a ResourceNotFound answer that names the extension; subscription, group, VM and bare NotFound answers are $false.
    .EXAMPLE
    Test-ExtensionNotFound -Message $_.Exception.Message -Name 'gnp-failing-script'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowEmptyString()][AllowNull()][string]$Message, [Parameter(Mandatory)][string]$Name)
    # Message text only: Az gives no stable structured code here. Exact text for a missing extension is confirmed by the live run.
    if ([string]::IsNullOrEmpty($Message)) { return $false }
    if ($Message -match 'SubscriptionNotFound|ResourceGroupNotFound') { return $false }
    $Message -match '\bResourceNotFound\b' -and $Message -match ('extensions/' + [regex]::Escape($Name) + '\b')
}

function Invoke-ShowExistenceVsState {
    <#
    .SYNOPSIS
    Prints the two checks; returns 0 when the state check passes, else 1. With -ExpectFailed returns 0 only for state Failed.
    .EXAMPLE
    $code = Invoke-ShowExistenceVsState -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string]$RunId,
        [Parameter(Mandatory)][string]$OutDir,
        [switch]$ExpectFailed
    )
    $sub = ''
    try {
        $ctx = Get-AzContext
        if (-not $ctx) { Write-Host 'Run Connect-AzAccount first. The check did not run.'; return 1 }
        $sub = $ctx.Subscription.Id

        $runFile = Join-Path $OutDir 'run.json'
        if (-not (Test-Path $runFile) -and -not $RunId) { throw 'No -RunId given and no run.json found' }
        $run = Read-DemoRun -OutDir $OutDir -RunId $RunId
        if (-not $run) { throw 'No run.json for this run' }
        Assert-DemoRunSubscription -Run $run -Current $sub
        if (-not ($run.PSObject.Properties['RogueVmName'] -and $run.RogueVmName)) { throw 'The run has no VM. Run scripts/New-RogueResource.ps1 first.' }

        try {
            $ext = Get-AzVMExtension -ResourceGroupName $run.ResourceGroup -VMName $run.RogueVmName -Name $script:ExtensionName -ErrorAction Stop
        }
        catch {
            # Only a not-found answer naming this extension means it is absent; any other failure means no read happened.
            if (-not (Test-ExtensionNotFound -Message $_.Exception.Message -Name $script:ExtensionName)) { throw }
            $ext = $null
        }
        if (-not $ext) {
            Write-Host "Existence check: FAIL (extension $($script:ExtensionName) not found). Run New-FailedExtension.ps1 first."
            return 1
        }
        $state = Get-ExtensionStateText -Extension $ext
        $existence = "Existence check: PASS (extension $($script:ExtensionName) found)"
        $stateLine = if ($state -eq 'Succeeded') { "State check:     PASS (ProvisioningState: $state)" } else { "State check:     FAIL (ProvisioningState: $state)" }
        Write-Host (ConvertTo-SafeText -Text (@($existence, $stateLine, 'One read of this extension, in this configuration, at this moment.') -join [Environment]::NewLine) -SubscriptionId $sub)
        if ($ExpectFailed) {
            if ($state -ne 'Failed') {
                Write-Host (ConvertTo-SafeText -Text "The state is $state, not Failed: this run does not show that existing is not working." -SubscriptionId $sub)
                return 1
            }
            return 0
        }
        if ($state -eq 'Succeeded') { return 0 }
        return 1
    }
    catch {
        Write-Host (ConvertTo-SafeText -Text "Show-ExistenceVsState failed: $($_.Exception.Message) The check did not run." -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../../out' }
    $code = Invoke-ShowExistenceVsState -RunId $RunId -OutDir $OutDir -ExpectFailed:$ExpectFailed
    if ($code -ne 0) { exit 1 }
}

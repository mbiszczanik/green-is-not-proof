function Test-WorkspaceHealth {
    <#
    .SYNOPSIS
    Health check for a Log Analytics workspace object. Strict demands ProvisioningState Succeeded and a non-empty PrivateLinkScopedResources; Lenient fails only on Failed or Deleting.
    .EXAMPLE
    Test-WorkspaceHealth -Workspace $ws -Mode Lenient
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Workspace,
        [ValidateSet('Strict', 'Lenient')][string]$Mode = 'Strict'
    )
    # StrictMode throws on a missing property, so read through PSObject.
    $state = $Workspace.PSObject.Properties['ProvisioningState']
    $state = if ($state) { [string]$state.Value } else { '' }
    if ($Mode -eq 'Lenient') { return ($state -notin 'Failed', 'Deleting') }

    $prop = $Workspace.PSObject.Properties['PrivateLinkScopedResources']
    $filled = $prop -and $null -ne $prop.Value -and @($prop.Value | Where-Object { "$_".Trim() }).Count -gt 0
    return ($state -eq 'Succeeded' -and [bool]$filled)
}

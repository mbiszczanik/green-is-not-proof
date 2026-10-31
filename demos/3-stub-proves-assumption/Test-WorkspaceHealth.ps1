function Get-HealthPropertyName {
    <#
    .SYNOPSIS
    Returns the workspace property the strict health check demands (the one place the name is defined).
    .EXAMPLE
    Get-HealthPropertyName
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    'PrivateLinkScopedResources'
}

function Test-HealthPropertyEmpty {
    <#
    .SYNOPSIS
    True when the demanded property is missing, null, an empty collection or blank text.
    .EXAMPLE
    Test-HealthPropertyEmpty -Workspace $ws
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][AllowNull()][object]$Workspace)
    # StrictMode throws on a missing property, so read through PSObject.
    $prop = $Workspace.PSObject.Properties[(Get-HealthPropertyName)]
    if (-not $prop -or $null -eq $prop.Value) { return $true }
    return (@($prop.Value | Where-Object { "$_".Trim() }).Count -eq 0)
}

function Test-WorkspaceHealth {
    <#
    .SYNOPSIS
    Health check for a Log Analytics workspace object. Strict demands ProvisioningState Succeeded and a non-empty demanded property; Lenient fails only on Failed or Deleting.
    .EXAMPLE
    Test-WorkspaceHealth -Workspace $ws -Mode Lenient
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Workspace,
        [ValidateSet('Strict', 'Lenient')][string]$Mode = 'Strict'
    )
    $state = $Workspace.PSObject.Properties['ProvisioningState']
    $state = if ($state) { [string]$state.Value } else { '' }
    if ($Mode -eq 'Lenient') { return ($state -notin 'Failed', 'Deleting') }
    return ($state -eq 'Succeeded' -and -not (Test-HealthPropertyEmpty -Workspace $Workspace))
}

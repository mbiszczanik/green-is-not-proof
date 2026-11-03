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
    Health check for a Log Analytics workspace object: passes only when ProvisioningState is Succeeded and the demanded property is non-empty.
    .DESCRIPTION
    Missing data never passes: a missing or blank ProvisioningState, a missing property or any other state returns false.
    .EXAMPLE
    Test-WorkspaceHealth -Workspace $ws
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][AllowNull()][object]$Workspace)
    if ($null -eq $Workspace) { return $false }
    $state = $Workspace.PSObject.Properties['ProvisioningState']
    $state = if ($state) { [string]$state.Value } else { '' }
    return ($state -eq 'Succeeded' -and -not (Test-HealthPropertyEmpty -Workspace $Workspace))
}

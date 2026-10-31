function New-DemoRunId {
    <#
    .SYNOPSIS
    Returns a run id (yyyyMMddHHmm) that names one demo run.
    .EXAMPLE
    New-DemoRunId
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Pure string builder, changes no state.')]
    [CmdletBinding()]
    [OutputType([string])]
    param([datetime]$Now = (Get-Date))
    $Now.ToString('yyyyMMddHHmm')
}

function Get-DemoResourceGroupName {
    <#
    .SYNOPSIS
    Returns the resource group name for a run id.
    .EXAMPLE
    Get-DemoResourceGroupName -RunId '202611181805'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$RunId)
    "rg-gnp-$RunId"
}

function Get-DemoTag {
    <#
    .SYNOPSIS
    Returns the tags every demo resource carries.
    .EXAMPLE
    Get-DemoTag -RunId '202611181805'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][string]$RunId)
    @{ project = 'green-is-not-proof'; runId = $RunId }
}

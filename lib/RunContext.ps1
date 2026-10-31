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

function Get-DemoExpectedSubscriptionId {
    <#
    .SYNOPSIS
    Returns the demo subscription id from GNP_SUBSCRIPTION_ID, else the first non-empty line of the config file; '' if neither exists.
    .EXAMPLE
    Get-DemoExpectedSubscriptionId
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$ConfigPath = (Join-Path $HOME '.config/green-is-not-proof/subscription.txt'))
    if ($env:GNP_SUBSCRIPTION_ID -and $env:GNP_SUBSCRIPTION_ID.Trim()) { return $env:GNP_SUBSCRIPTION_ID.Trim() }
    if (Test-Path -LiteralPath $ConfigPath) {
        $line = Get-Content -LiteralPath $ConfigPath | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 1
        if ($line) { return [string]$line }
    }
    ''
}

function Assert-DemoSubscription {
    <#
    .SYNOPSIS
    Throws unless the current subscription equals the expected one; neither id is printed.
    .EXAMPLE
    Assert-DemoSubscription -Expected $expected -Current $ctx.Subscription.Id
    #>
    [CmdletBinding()]
    param([AllowEmptyString()][AllowNull()][string]$Expected, [AllowEmptyString()][AllowNull()][string]$Current)
    if ([string]::IsNullOrWhiteSpace($Expected)) {
        throw 'Expected demo subscription not configured (GNP_SUBSCRIPTION_ID or ~/.config/green-is-not-proof/subscription.txt).'
    }
    if ($Expected -ne $Current) { throw 'Current Azure subscription is not the demo subscription. Run Set-AzContext first.' }
}

function Assert-DemoRunSubscription {
    <#
    .SYNOPSIS
    Pins the current subscription to the run record's SubscriptionId, or to the configured id when there is no record.
    .EXAMPLE
    Assert-DemoRunSubscription -Run $run -Current $ctx.Subscription.Id
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Run, [AllowEmptyString()][AllowNull()][string]$Current)
    if ($Run) {
        $p = $Run.PSObject.Properties['SubscriptionId']
        if (-not ($p -and $p.Value)) { throw 'run.json has no SubscriptionId; this run predates subscription pinning. Tear it down with the run''s own subscription selected, then start a new run.' }
        Assert-DemoSubscription -Expected ([string]$p.Value) -Current $Current
        return
    }
    Assert-DemoSubscription -Expected (Get-DemoExpectedSubscriptionId) -Current $Current
}

function Read-DemoRun {
    <#
    .SYNOPSIS
    Returns the run.json record under OutDir when it exists and matches RunId (or no RunId is given); else $null.
    .EXAMPLE
    Read-DemoRun -OutDir ./out -RunId 202611181805
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$OutDir, [string]$RunId)
    $file = Join-Path $OutDir 'run.json'
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    $run = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    if ($RunId -and $run.RunId -ne $RunId) { return $null }
    $run
}

function Test-DemoResourceGroup {
    <#
    .SYNOPSIS
    Returns $true if the resource group exists, $false only on a not-found error; any other error throws.
    .EXAMPLE
    Test-DemoResourceGroup -Name rg-gnp-202611181805
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Name)
    try { return [bool](Get-AzResourceGroup -Name $Name -ErrorAction Stop) }
    catch {
        # Exact Az text for a missing group is confirmed by the live run. A missing subscription must never read as a missing group.
        $m = $_.Exception.Message
        if ($m -notmatch 'SubscriptionNotFound' -and $m -match 'ResourceGroupNotFound|could not be found|Provided resource group does not exist') { return $false }
        throw
    }
}

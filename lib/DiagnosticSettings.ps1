# Observed live on 2026-11-04: both types without diagnostic settings (devtestlab schedules, VM extensions) returned
# `[ResourceTypeNotSupported] : The resource type '...' does not support diagnostic settings.` A bare BadRequest is not
# treated as "unsupported"; it throws, so a failed read never counts as no settings.
$script:UnsupportedDiagnosticPattern = 'does not support diagnostic settings|ResourceTypeNotSupported'

function Get-DemoDiagnosticSettingName {
    <#
    .SYNOPSIS
    Returns the names of the diagnostic settings listed on a resource; none for a type that does not support them.
    .DESCRIPTION
    Any other list failure throws, so a failed read never counts as "no settings".
    .EXAMPLE
    Get-DemoDiagnosticSettingName -ResourceId $storage.Id
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)][string]$ResourceId)
    try { $settings = @(Get-AzDiagnosticSetting -ResourceId $ResourceId -ErrorAction Stop) }
    catch {
        if ($_.Exception.Message -match $script:UnsupportedDiagnosticPattern) { return @() }
        throw
    }
    @($settings | ForEach-Object { [string]$_.Name })
}

function Remove-DemoDiagnosticSetting {
    <#
    .SYNOPSIS
    Removes every diagnostic setting on a resource, whatever its name, and returns how many were removed.
    .DESCRIPTION
    A list or remove failure throws. A resource type that does not support diagnostic settings counts as zero.
    .EXAMPLE
    Remove-DemoDiagnosticSetting -ResourceId $storage.Id
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Teardown helper, always acts.')]
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][string]$ResourceId,
        [string]$SubscriptionId
    )
    try {
        $settings = @(Get-AzDiagnosticSetting -ResourceId $ResourceId -ErrorAction Stop)
    }
    catch {
        if ($_.Exception.Message -match $script:UnsupportedDiagnosticPattern) {
            Write-Host (ConvertTo-SafeText -Text "No diagnostic settings supported on $ResourceId ($($_.Exception.Message))" -SubscriptionId $SubscriptionId)
            return 0
        }
        throw
    }
    foreach ($s in $settings) {
        Remove-AzDiagnosticSetting -ResourceId $ResourceId -Name $s.Name -ErrorAction Stop | Out-Null
    }
    $settings.Count
}

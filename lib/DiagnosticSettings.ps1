# Texts Azure returned for a type without diagnostic settings: ResourceTypeNotSupported (observed live for
# microsoft.devtestlab/schedules). A bare BadRequest counts only when it also names diagnostic settings; the VM
# extension text was not captured, so the teardown prints the raw message to record it.
$script:UnsupportedDiagnosticPattern = 'does not support diagnostic settings|ResourceTypeNotSupported|BadRequest(?=[\s\S]*diagnostic)'

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

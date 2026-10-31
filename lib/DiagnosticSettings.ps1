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
        if ($_.Exception.Message -match 'does not support diagnostic settings|ResourceTypeNotSupported|BadRequest') {
            Write-Host (ConvertTo-MaskedText -Text "No diagnostic settings supported on $ResourceId" -SubscriptionId $SubscriptionId)
            return 0
        }
        throw
    }
    foreach ($s in $settings) {
        Remove-AzDiagnosticSetting -ResourceId $ResourceId -Name $s.Name -ErrorAction Stop
    }
    $settings.Count
}

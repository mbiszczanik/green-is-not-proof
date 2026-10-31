function ConvertTo-MaskedText {
    <#
    .SYNOPSIS
    Replaces every occurrence of the subscription id (case-insensitive) with <sub>.
    .EXAMPLE
    ConvertTo-MaskedText -Text $message -SubscriptionId $id
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Text,
        [AllowEmptyString()][AllowNull()][string]$SubscriptionId
    )
    if ([string]::IsNullOrEmpty($SubscriptionId) -or [string]::IsNullOrEmpty($Text)) { return $Text }
    [regex]::Replace($Text, [regex]::Escape($SubscriptionId), '<sub>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Write-DemoOutput {
    <#
    .SYNOPSIS
    Writes an object as table text with the subscription id masked.
    .EXAMPLE
    Get-AzResourceGroup | Write-DemoOutput -SubscriptionId $id
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][object]$InputObject,
        [string]$SubscriptionId
    )
    begin { $items = [System.Collections.Generic.List[object]]::new() }
    process { $items.Add($InputObject) }
    end {
        $text = ($items | Format-Table -AutoSize | Out-String).TrimEnd()
        Write-Output (ConvertTo-MaskedText -Text $text -SubscriptionId $SubscriptionId)
    }
}

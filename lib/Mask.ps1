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

function ConvertTo-SafeText {
    <#
    .SYNOPSIS
    Masks the subscription id (<sub>), e-mail addresses (<email>) and every GUID not on the public-content allow list (<guid>).
    .EXAMPLE
    ConvertTo-SafeText -Text $_.Exception.Message -SubscriptionId $sub
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Text,
        [AllowEmptyString()][AllowNull()][string]$SubscriptionId,
        [string]$AllowListPath = (Join-Path $PSScriptRoot '../tools/public-content-allow.txt')
    )
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $allowed = @{}
    if (Test-Path -LiteralPath $AllowListPath) {
        foreach ($l in Get-Content -LiteralPath $AllowListPath) {
            $t = $l.Trim()
            if ($t -and -not $t.StartsWith('#')) { $allowed[$t.ToLowerInvariant()] = $true }
        }
    }
    $out = ConvertTo-MaskedText -Text $Text -SubscriptionId $SubscriptionId
    $out = [regex]::Replace($out, '[\w.+-]+@[\w-]+\.[\w.-]+', '<email>')
    [regex]::Replace($out, '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}', {
            param($m)
            if ($allowed.ContainsKey($m.Value.ToLowerInvariant())) { $m.Value } else { '<guid>' }
        }.GetNewClosure())
}

function Write-DemoOutput {
    <#
    .SYNOPSIS
    Writes an object as table text with ConvertTo-SafeText applied to every value.
    .EXAMPLE
    Get-AzResourceGroup | Write-DemoOutput -SubscriptionId $id
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][object]$InputObject,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SubscriptionId
    )
    begin { $items = [System.Collections.Generic.List[object]]::new() }
    process {
        # Mask values before Format-Table, which can truncate or wrap a cell and split the id.
        if ($InputObject -is [string] -or $InputObject.GetType().IsPrimitive) {
            $items.Add((ConvertTo-SafeText -Text ([string]$InputObject) -SubscriptionId $SubscriptionId))
            return
        }
        $masked = [ordered]@{}
        foreach ($p in $InputObject.PSObject.Properties) {
            $masked[$p.Name] = ConvertTo-SafeText -Text ([string]$p.Value) -SubscriptionId $SubscriptionId
        }
        $items.Add([pscustomobject]$masked)
    }
    end {
        $text = ($items | Format-Table -AutoSize | Out-String -Width 4096).TrimEnd()
        Write-Output (ConvertTo-SafeText -Text $text -SubscriptionId $SubscriptionId)
    }
}

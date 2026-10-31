$script:DefaultFetch = {
    param([hashtable]$Item, [string]$Region)
    $clauses = @("armRegionName eq '$Region'", "type eq 'Consumption'", "serviceName eq '$($Item.ServiceName)'")
    if ($Item.ArmSkuName) { $clauses += "armSkuName eq '$($Item.ArmSkuName)'" }
    if ($Item.MeterName) { $clauses += "meterName eq '$($Item.MeterName)'" }
    if ($Item.ProductName) { $clauses += "productName eq '$($Item.ProductName)'" }
    $uri = "https://prices.azure.com/api/retail/prices?currencyCode='EUR'&`$filter=" + [uri]::EscapeDataString($clauses -join ' and ')
    while ($uri) {
        $page = Invoke-RestMethod -Uri $uri -Method Get
        $page.Items
        $uri = $page.NextPageLink
    }
}

function Get-RetailPrice {
    <#
    .SYNOPSIS
    Returns the EUR unit price of one demo item (Linux pay-as-you-go, no Spot or Low Priority).
    .EXAMPLE
    Get-RetailPrice -Item $items[0] -Region swedencentral
    #>
    [CmdletBinding()]
    [OutputType([decimal])]
    param(
        [Parameter(Mandatory)][hashtable]$Item,
        [Parameter(Mandatory)][string]$Region,
        [scriptblock]$Fetch = $script:DefaultFetch
    )
    $found = @(& $Fetch $Item $Region | Where-Object {
            $_.meterName -notmatch 'Spot|Low Priority' -and $_.productName -notmatch 'Windows|Spot' -and
            (-not $Item.ContainsKey('TierMinimumUnits') -or [decimal]$_.tierMinimumUnits -eq [decimal]$Item.TierMinimumUnits)
        } | Sort-Object -Property meterName)
    if ($found.Count -eq 0) { throw "No retail price for $($Item.Name)" }
    [decimal]$found[0].retailPrice
}

function Get-DemoRunCostEstimate {
    <#
    .SYNOPSIS
    Estimates a demo run's cost in EUR from the Azure Retail Prices API.
    .DESCRIPTION
    Unit Hour: price x quantity x hours. Month: price / 730 x quantity x hours. Run: price x quantity once.
    .EXAMPLE
    Get-DemoRunCostEstimate -Items (Import-PowerShellDataFile ./config/demo-resources.psd1).Items -Region swedencentral
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable[]]$Items,
        [Parameter(Mandatory)][string]$Region,
        [decimal]$Hours = 2,
        [scriptblock]$Fetch = $script:DefaultFetch
    )
    $lines = foreach ($item in $Items) {
        $unit = [decimal](Get-RetailPrice -Item $item -Region $Region -Fetch $Fetch)
        $cost = switch ($item.Unit) {
            'Hour' { $unit * $item.Quantity * $Hours }
            'Month' { $unit / 730 * $item.Quantity * $Hours }
            'Run' { $unit * $item.Quantity }
            default { throw "Unknown unit '$($item.Unit)' for $($item.Name)" }
        }
        [pscustomobject]@{ Name = $item.Name; Unit = $item.Unit; UnitPriceEur = $unit; Quantity = $item.Quantity; CostEur = [math]::Round([decimal]$cost, 6) }
    }
    $total = [decimal]0
    foreach ($l in $lines) { $total += $l.CostEur }
    [pscustomobject]@{ TotalEur = $total; Lines = @($lines); PriceDate = Get-Date -Format 'yyyy-MM-dd' }
}

function Assert-DemoRunBudget {
    <#
    .SYNOPSIS
    Throws when the estimate exceeds the limit.
    .EXAMPLE
    Assert-DemoRunBudget -Estimate $estimate -LimitEur 2
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Estimate,
        [decimal]$LimitEur = 2
    )
    if ($Estimate.TotalEur -gt $LimitEur) { throw "Run estimate $($Estimate.TotalEur) EUR exceeds limit $LimitEur EUR" }
}

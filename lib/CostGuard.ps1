function Get-HttpStatusCode {
    param($ErrorRecord)
    $ex = $ErrorRecord.Exception
    $code = $null
    if ($ex.PSObject.Properties['StatusCode']) { $code = $ex.StatusCode }
    if ($null -eq $code -and $ex.PSObject.Properties['Response'] -and $null -ne $ex.Response -and $ex.Response.PSObject.Properties['StatusCode']) { $code = $ex.Response.StatusCode }
    if ($null -eq $code) { return $null }
    try { [int]$code } catch { $null }
}

function Invoke-RetailPricePage {
    param([Parameter(Mandatory)][string]$Uri, [string]$ItemName = '?', [int]$MaxRetries = 5)
    for ($attempt = 0; ; $attempt++) {
        try { return Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop }
        catch {
            $status = Get-HttpStatusCode -ErrorRecord $_
            $retryable = $null -ne $status -and ($status -eq 429 -or ($status -ge 500 -and $status -le 599))
            if (-not $retryable -or $attempt -ge $MaxRetries) {
                $shown = if ($null -ne $status) { "HTTP $status" } else { 'no HTTP status' }
                throw "Retail price request failed for ${Uri} (item $ItemName, $shown): $($_.Exception.Message)"
            }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt + 1))
        }
    }
}

function Get-RetailPriceItem {
    param([hashtable]$Item, [string]$Region, [int]$MaxPages = 50)
    $clauses = @("armRegionName eq '$Region'", "type eq 'Consumption'", "serviceName eq '$($Item.ServiceName)'")
    if ($Item['ArmSkuName']) { $clauses += "armSkuName eq '$($Item['ArmSkuName'])'" }
    if ($Item['MeterName']) { $clauses += "meterName eq '$($Item['MeterName'])'" }
    if ($Item['ProductName']) { $clauses += "productName eq '$($Item['ProductName'])'" }
    $uri = "https://prices.azure.com/api/retail/prices?currencyCode='EUR'&`$filter=" + [uri]::EscapeDataString($clauses -join ' and ')
    $pages = 0
    while ($uri) {
        if (++$pages -gt $MaxPages) { throw "Retail price paging exceeded $MaxPages pages for $($Item.Name)" }
        $page = Invoke-RetailPricePage -Uri $uri -ItemName $Item.Name
        $page.Items
        $uri = $page.NextPageLink
    }
}

$script:DefaultFetch = { param([hashtable]$Item, [string]$Region) Get-RetailPriceItem -Item $Item -Region $Region }

function Resolve-RetailPrice {
    param([hashtable]$Item, [string]$Region, [scriptblock]$Fetch)
    $found = @(& $Fetch $Item $Region | Where-Object {
            $_.meterName -notmatch 'Spot|Low Priority' -and $_.productName -notmatch 'Windows|Spot' -and
            (-not $Item.ContainsKey('TierMinimumUnits') -or [decimal]$_.tierMinimumUnits -eq [decimal]$Item.TierMinimumUnits)
        } | Sort-Object -Property meterName)
    if ($found.Count -eq 0) { throw "No retail price for $($Item.Name)" }
    $price = $found[0].retailPrice
    if ($null -eq $price) { throw "Invalid retail price for $($Item.Name)" }
    try { $value = [decimal]$price } catch { throw "Retail price for $($Item.Name) is not a number: '$price'" }
    if ($value -le 0) { throw "Invalid retail price for $($Item.Name)" }
    if ($found.Count -gt 1) { Write-Warning "Several retail prices matched $($Item.Name); using $($found[0].meterName) $price" }
    [pscustomobject]@{ Price = $value; Matches = $found.Count }
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
    (Resolve-RetailPrice -Item $Item -Region $Region -Fetch $Fetch).Price
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
        $resolved = Resolve-RetailPrice -Item $item -Region $Region -Fetch $Fetch
        $unit = $resolved.Price
        $cost = switch ($item.Unit) {
            'Hour' { $unit * $item.Quantity * $Hours }
            'Month' { $unit / 730 * $item.Quantity * $Hours }
            'Run' { $unit * $item.Quantity }
            default { throw "Unknown unit '$($item.Unit)' for $($item.Name)" }
        }
        [pscustomobject]@{ Name = $item.Name; Unit = $item.Unit; UnitPriceEur = $unit; Matches = $resolved.Matches; Quantity = $item.Quantity; CostEur = [math]::Round([decimal]$cost, 6) }
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

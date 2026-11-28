BeforeAll {
    . $PSScriptRoot/../lib/CostGuard.ps1
    function Get-FakePrice($Price, $Meter = 'm', $Product = 'p', $Tier = 0) {
        [pscustomobject]@{ retailPrice = $Price; unitOfMeasure = '1 Hour'; meterName = $Meter; productName = $Product; skuName = 's'; tierMinimumUnits = $Tier }
    }
}

Describe 'Get-DemoRunCostEstimate' {
    It 'sums hourly and monthly items over hours' {
        $items = @(
            @{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' }
            @{ Name = 'disk'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Month' }
        )
        $fetch = { param($Item) if ($Item.Name -eq 'vm') { Get-FakePrice 0.01 } else { Get-FakePrice 7.30 } }
        $e = Get-DemoRunCostEstimate -Items $items -Region 'r' -Hours 2 -Fetch $fetch
        $e.TotalEur | Should -Be 0.04
        $e.Lines.Count | Should -Be 2
    }
    It 'per-GB item uses quantity once per run' {
        $items = @(@{ Name = 'law'; ServiceName = 'x'; ArmSkuName = ''; MeterName = 'x'; Quantity = 0.1; Unit = 'Run' })
        $e = Get-DemoRunCostEstimate -Items $items -Region 'r' -Hours 5 -Fetch { Get-FakePrice 2.30 }
        $e.TotalEur | Should -Be 0.23
    }
    It 'missing price stops the run' {
        $items = @(@{ Name = 'ghost'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' })
        { Get-DemoRunCostEstimate -Items $items -Region 'r' -Fetch { @() } } | Should -Throw 'No retail price for ghost'
    }
    It 'fetch failure stops the run' {
        $items = @(@{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' })
        { Get-DemoRunCostEstimate -Items $items -Region 'r' -Fetch { throw 'network down' } } | Should -Throw '*network down*'
    }
    It 'takes the first match sorted by meter name and skips Spot, Low Priority and Windows' {
        $item = @{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' }
        $fetch = {
            Get-FakePrice 9 'B1s Spot'; Get-FakePrice 8 'B1s Low Priority'; Get-FakePrice 7 'B1s' 'Virtual Machines BS Series Windows'
            Get-FakePrice 0.5 'B1s Z'; Get-FakePrice 0.2 'B1s A' }
        Get-RetailPrice -Item $item -Region 'r' -Fetch $fetch -WarningAction SilentlyContinue | Should -Be 0.2
    }
    It 'zero or missing price stops the run' {
        $item = @{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' }
        { Get-RetailPrice -Item $item -Region 'r' -Fetch { Get-FakePrice 0 } } | Should -Throw 'Invalid retail price for vm'
        { Get-RetailPrice -Item $item -Region 'r' -Fetch { Get-FakePrice $null } } | Should -Throw 'Invalid retail price for vm'
    }
    It 'non-numeric price stops the run with the item name' {
        $item = @{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' }
        { Get-RetailPrice -Item $item -Region 'r' -Fetch { Get-FakePrice 'abc' } } | Should -Throw '*vm*not a number*'
    }
    It 'tiered meter uses the tier at or above TierMinimumUnits' {
        $item = @{ Name = 'law'; ServiceName = 'x'; MeterName = 'x'; TierMinimumUnits = 5; Quantity = 1; Unit = 'Run' }
        Get-RetailPrice -Item $item -Region 'r' -Fetch { Get-FakePrice 0 'Ingestion' 'p' 0; Get-FakePrice 2.63 'Ingestion' 'p' 5 } | Should -Be 2.63
    }
    It 'warns and counts matches when several prices match' {
        $items = @(@{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' })
        $e = Get-DemoRunCostEstimate -Items $items -Region 'r' -Fetch { Get-FakePrice 0.5 'B Z'; Get-FakePrice 0.2 'B A' } -WarningVariable w -WarningAction SilentlyContinue
        $w | Should -Match 'Several retail prices matched vm; using B A'
        $e.Lines[0].Matches | Should -Be 2
    }
    It 'unknown unit throws' {
        $items = @(@{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Week' })
        { Get-DemoRunCostEstimate -Items $items -Region 'r' -Fetch { Get-FakePrice 0.5 } } | Should -Throw "Unknown unit 'Week'*"
    }
    It 'estimate carries price date' {
        $items = @(@{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' })
        $e = Get-DemoRunCostEstimate -Items $items -Region 'r' -Fetch { Get-FakePrice 0.01 }
        $e.PriceDate | Should -Be (Get-Date -Format 'yyyy-MM-dd')
    }
}

Describe 'Assert-DemoRunBudget' {
    It 'budget over limit throws' {
        $est = [pscustomobject]@{ TotalEur = [decimal]2.5; Lines = @(); PriceDate = '2026-01-01' }
        { Assert-DemoRunBudget -Estimate $est -LimitEur 2 } | Should -Throw 'Run estimate 2.5 EUR exceeds limit 2 EUR'
    }
    It 'budget under limit passes' {
        $est = [pscustomobject]@{ TotalEur = [decimal]0.5; Lines = @(); PriceDate = '2026-01-01' }
        { Assert-DemoRunBudget -Estimate $est -LimitEur 2 } | Should -Not -Throw
    }
}

Describe 'Get-RetailPriceItem' {
    BeforeAll { $script:item = @{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' } }
    It 'default fetch stops on a failing first page' {
        Mock Invoke-RestMethod { throw 'boom' }
        { Get-RetailPriceItem -Item $script:item -Region 'r' } | Should -Throw '*Retail price request failed for https://prices.azure.com*boom*'
    }
    It 'default fetch stops on a failing second page' {
        $script:calls = 0
        Mock Invoke-RestMethod {
            $script:calls++
            if ($script:calls -eq 1) { [pscustomobject]@{ Items = @(Get-FakePrice 1); NextPageLink = 'https://prices.azure.com/page2' } }
            else { throw 'page2 down' }
        }
        { Get-RetailPriceItem -Item $script:item -Region 'r' } | Should -Throw '*page2*page2 down*'
        $script:calls | Should -Be 2
    }
    It 'default fetch follows NextPageLink' {
        $script:calls = 0
        Mock Invoke-RestMethod {
            $script:calls++
            if ($script:calls -eq 1) { [pscustomobject]@{ Items = @(Get-FakePrice 1 'a'); NextPageLink = 'https://prices.azure.com/page2' } }
            else { [pscustomobject]@{ Items = @(Get-FakePrice 2 'b'); NextPageLink = $null } }
        }
        @(Get-RetailPriceItem -Item $script:item -Region 'r').Count | Should -Be 2
    }
    It 'default fetch stops at the page cap' {
        Mock Invoke-RestMethod { [pscustomobject]@{ Items = @(Get-FakePrice 1); NextPageLink = 'https://prices.azure.com/loop' } }
        { Get-RetailPriceItem -Item $script:item -Region 'r' -MaxPages 3 } | Should -Throw '*exceeded 3 pages*'
    }
}

Describe 'Invoke-RetailPricePage retry' {
    BeforeAll {
        $script:item = @{ Name = 'vm'; ServiceName = 'x'; ArmSkuName = 'x'; MeterName = 'x'; Quantity = 1; Unit = 'Hour' }
        function Get-HttpErrorFake($Code, $OnResponse = $false) {
            $ex = [System.Exception]::new("status $Code")
            if ($OnResponse) { $ex | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{ StatusCode = $Code }) }
            else { $ex | Add-Member -NotePropertyName StatusCode -NotePropertyValue $Code }
            $ex
        }
    }
    BeforeEach {
        $script:calls = 0
        $script:waits = @()
        Mock Start-Sleep { $script:waits += $Seconds }
    }
    It 'succeeds after a 429' {
        Mock Invoke-RestMethod {
            $script:calls++
            if ($script:calls -le 2) { throw (Get-HttpErrorFake 429) }
            [pscustomobject]@{ Items = @(Get-FakePrice 1); NextPageLink = $null }
        }
        Set-StrictMode -Version Latest
        @(Get-RetailPriceItem -Item $script:item -Region 'r').Count | Should -Be 1
        $script:calls | Should -Be 3
        $script:waits.Count | Should -Be 2
    }
    It 'succeeds after a 5xx' {
        Mock Invoke-RestMethod {
            $script:calls++
            if ($script:calls -eq 1) { throw (Get-HttpErrorFake 503) }
            [pscustomobject]@{ Items = @(Get-FakePrice 1); NextPageLink = $null }
        }
        Set-StrictMode -Version Latest
        @(Get-RetailPriceItem -Item $script:item -Region 'r').Count | Should -Be 1
        $script:calls | Should -Be 2
    }
    It 'retries a 429 whose status is only on Response, under strict mode' {
        Mock Invoke-RestMethod {
            $script:calls++
            if ($script:calls -eq 1) { throw (Get-HttpErrorFake 429 $true) }
            [pscustomobject]@{ Items = @(Get-FakePrice 1); NextPageLink = $null }
        }
        Set-StrictMode -Version Latest
        @(Get-RetailPriceItem -Item $script:item -Region 'r').Count | Should -Be 1
        $script:calls | Should -Be 2
    }
    It 'fails after 5 retries naming item and status, with growing waits' {
        Mock Invoke-RestMethod { $script:calls++; throw (Get-HttpErrorFake 429) }
        Set-StrictMode -Version Latest
        { Get-RetailPriceItem -Item $script:item -Region 'r' } | Should -Throw '*item vm*HTTP 429*'
        $script:calls | Should -Be 6
        $script:waits.Count | Should -Be 5
        for ($i = 1; $i -lt 5; $i++) { $script:waits[$i] | Should -BeGreaterThan $script:waits[$i - 1] }
    }
    It 'does not retry another status' {
        Mock Invoke-RestMethod { $script:calls++; throw (Get-HttpErrorFake 404) }
        Set-StrictMode -Version Latest
        { Get-RetailPriceItem -Item $script:item -Region 'r' } | Should -Throw '*item vm*HTTP 404*'
        $script:calls | Should -Be 1
        $script:waits.Count | Should -Be 0
    }
    It 'fails at once on an error without a status, keeping the message and item, under strict mode' {
        Mock Invoke-RestMethod { $script:calls++; throw 'plain boom' }
        Set-StrictMode -Version Latest
        { Get-RetailPriceItem -Item $script:item -Region 'r' } | Should -Throw '*item vm*plain boom*'
        $script:calls | Should -Be 1
        $script:waits.Count | Should -Be 0
    }
}

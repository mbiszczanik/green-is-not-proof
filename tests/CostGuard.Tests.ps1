BeforeAll {
    . $PSScriptRoot/../lib/CostGuard.ps1
    function Get-FakePrice($Price, $Meter = 'm', $Product = 'p') {
        [pscustomobject]@{ retailPrice = $Price; unitOfMeasure = '1 Hour'; meterName = $Meter; productName = $Product; skuName = 's' }
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
        Get-RetailPrice -Item $item -Region 'r' -Fetch $fetch | Should -Be 0.2
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

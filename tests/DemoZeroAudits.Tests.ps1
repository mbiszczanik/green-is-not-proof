BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $script:StubNames = 'Get-AzContext', 'Get-AzResource'
    Set-Item -Path 'function:global:Get-AzContext' -Value ([scriptblock]::Create('param()'))
    Set-Item -Path 'function:global:Get-AzResource' -Value ([scriptblock]::Create('param($ResourceGroupName, $TagName, $TagValue)'))
    $script:Dir = "$PSScriptRoot/../demos/0-tag-is-not-ownership"
    . $script:Dir/Invoke-TagAudit.ps1
    . $script:Dir/Invoke-OwnershipAudit.ps1
    $script:RunIdValue = '202611181805'

    function script:Res($Name, $Type, $Tags = @{ project = 'green-is-not-proof'; runId = '202611181805' }) {
        [pscustomobject]@{ Name = $Name; ResourceType = $Type; Tags = $Tags
            Id = "/subscriptions/$($script:Sub)/resourceGroups/rg-gnp-202611181805/providers/$Type/$Name" }
    }
    # Bodies write text with Write-Host and return the exit code last.
    function script:Invoke-Capture([scriptblock]$Block) {
        $all = @(& $Block 6>&1)
        [pscustomobject]@{ Code = $all[-1]; Text = (($all | Select-Object -SkipLast 1 | ForEach-Object { "$_" }) -join "`n") }
    }
    function script:Initialize-Mock {
        $script:inv = @(
            (Res 'vnet-gnp' 'Microsoft.Network/virtualNetworks'),
            (Res 'log-gnp-202611181805' 'Microsoft.OperationalInsights/workspaces'),
            (Res 'stgnp202611181805' 'Microsoft.Storage/storageAccounts'),
            (Res 'vm-traffic' 'Microsoft.Compute/virtualMachines'),
            (Res 'vm-traffic-nic' 'Microsoft.Network/networkInterfaces'),
            (Res 'vm-traffic_OsDisk_1_abc123' 'Microsoft.Compute/disks')
        )
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $script:Sub } } }
        Mock Get-AzResource { $script:inv }
    }
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

Describe 'Invoke-TagAudit' {
    BeforeEach { Initialize-Mock }

    It 'is green with the rogue VM present' {
        $r = Invoke-Capture { Invoke-TagAudit -RunId $script:RunIdValue -OutDir $TestDrive }
        $r.Code | Should -Be 0
        ($r.Text -split "`n")[-1] | Should -Be 'All 6 resources carry project tags: OK'
        $r.Text | Should -Match 'vm-traffic'
    }

    It 'masks the subscription id' {
        (Invoke-Capture { Invoke-TagAudit -RunId $script:RunIdValue -OutDir $TestDrive }).Text | Should -Not -Match $script:Sub
    }

    It 'ignores resources from another run' {
        $script:inv += Res 'other' 'Microsoft.Network/virtualNetworks' @{ project = 'green-is-not-proof'; runId = '999999999999' }
        (Invoke-Capture { Invoke-TagAudit -RunId $script:RunIdValue -OutDir $TestDrive }).Text | Should -Match 'All 6 resources'
    }

    It 'fails without a run id and no run.json' {
        (Invoke-Capture { Invoke-TagAudit -OutDir (Join-Path $TestDrive 'none') }).Code | Should -Be 1
    }
}

Describe 'Invoke-OwnershipAudit' {
    BeforeEach { Initialize-Mock }

    It 'returns 1 and lists vm-traffic, its NIC and OS disk' {
        $r = Invoke-Capture { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'Not declared in code:'
        $r.Text | Should -Match 'vm-traffic-nic'
        $r.Text | Should -Match 'vm-traffic_OsDisk_1_abc123'
        $r.Text | Should -Not -Match 'vnet-gnp'
    }

    It 'masks the subscription id in the listing' {
        $r = Invoke-Capture { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }
        $r.Text | Should -Not -Match $script:Sub
        $r.Text | Should -Match '<sub>'
    }

    It 'returns 0 when everything is declared' {
        $script:inv = @($script:inv | Select-Object -First 3)
        $r = Invoke-Capture { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }
        $r.Code | Should -Be 0
        $r.Text | Should -Match 'All 3 resources are declared in code: OK'
    }

    It 'returns 1 on an empty inventory' {
        $script:inv = @()
        $r = Invoke-Capture { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'Empty inventory'
    }
}

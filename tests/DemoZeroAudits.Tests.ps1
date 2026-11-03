BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $script:StubNames = 'Get-AzContext', 'Get-AzResource', 'Get-AzResourceGroupDeployment', 'Get-AzResourceGroupDeploymentOperation'
    Set-Item -Path 'function:global:Get-AzContext' -Value ([scriptblock]::Create('param()'))
    Set-Item -Path 'function:global:Get-AzResource' -Value ([scriptblock]::Create('param($ResourceGroupName, $TagName, $TagValue)'))
    Set-Item -Path 'function:global:Get-AzResourceGroupDeployment' -Value ([scriptblock]::Create('param($ResourceGroupName, $Name)'))
    Set-Item -Path 'function:global:Get-AzResourceGroupDeploymentOperation' -Value ([scriptblock]::Create('param($ResourceGroupName, $DeploymentName)'))
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
        Mock Get-DemoExpectedSubscriptionId { $script:Sub }
        # The deployment record lists the three declared resources, an extension resource and an output step.
        Mock Get-AzResourceGroupDeployment { [pscustomobject]@{ ProvisioningState = 'Succeeded' } }
        $script:ops = @($script:inv | Select-Object -First 3 | ForEach-Object { [pscustomobject]@{ TargetResource = $_.Id.ToUpperInvariant() } }) +
        @([pscustomobject]@{ TargetResource = "$($script:inv[2].Id)/blobServices/default/providers/Microsoft.Insights/diagnosticSettings/diag-to-log" },
            [pscustomobject]@{ TargetResource = $null })
        Mock Get-AzResourceGroupDeploymentOperation { $script:ops }
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

Describe 'subscription pinning in the audits' {
    BeforeEach { Initialize-Mock }

    It 'both audits refuse a different subscription and read no resources' {
        Mock Get-DemoExpectedSubscriptionId { [guid]::NewGuid().ToString() }
        foreach ($b in { Invoke-TagAudit -RunId $script:RunIdValue -OutDir $TestDrive }, { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }) {
            $r = Invoke-Capture $b
            $r.Code | Should -Be 1
            $r.Text | Should -Match 'not the demo subscription'
        }
        Should -Invoke Get-AzResource -Times 0 -Exactly
    }

    It 'a run.json without SubscriptionId is refused' {
        $d = Join-Path $TestDrive 'pin'
        $null = New-Item -ItemType Directory -Path $d
        @{ RunId = $script:RunIdValue } | ConvertTo-Json | Set-Content (Join-Path $d 'run.json')
        $r = Invoke-Capture { Invoke-TagAudit -OutDir $d }
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'no SubscriptionId'
        Should -Invoke Get-AzResource -Times 0 -Exactly
    }
}

Describe 'Invoke-OwnershipAudit' {
    BeforeEach { Initialize-Mock }

    It 'returns 1 and lists vm-traffic, its NIC and OS disk' {
        $r = Invoke-Capture { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'Not in the deployment record:'
        $r.Text | Should -Match 'vm-traffic '
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
        $r.Text | Should -Match 'All 3 resources are in the deployment record: OK'
    }

    It 'reads the record of the run''s deployment' {
        $null = Invoke-Capture { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }
        Should -Invoke Get-AzResourceGroupDeploymentOperation -Times 1 -Exactly -ParameterFilter { $ResourceGroupName -eq 'rg-gnp-202611181805' -and $DeploymentName -eq 'declared-202611181805' }
    }

    It 'returns 1 and names the record when the deployment record is missing' {
        Mock Get-AzResourceGroupDeployment { throw 'DeploymentNotFound' }
        $r = Invoke-Capture { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'Deployment record declared-202611181805 not readable'
        $r.Text | Should -Not -Match 'OK'
    }

    It 'returns 1 when the deployment did not succeed' {
        Mock Get-AzResourceGroupDeployment { [pscustomobject]@{ ProvisioningState = 'Failed' } }
        (Invoke-Capture { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }).Code | Should -Be 1
    }

    It 'returns 1 on an empty inventory' {
        $script:inv = @()
        $r = Invoke-Capture { Invoke-OwnershipAudit -RunId $script:RunIdValue -OutDir $TestDrive }
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'Empty inventory'
    }
}

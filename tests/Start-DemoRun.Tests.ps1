BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $stubs = @{
        'Get-AzContext'                            = 'param()'
        'New-AzResourceGroup'                      = 'param($Name, $Location, $Tag)'
        'New-AzOperationalInsightsWorkspace'       = 'param($ResourceGroupName, $Name, $Location, $Sku, $Tag)'
        'New-AzStorageAccount'                     = 'param($ResourceGroupName, $Name, $Location, $SkuName, $Kind, $Tag)'
        'New-AzDiagnosticSettingLogSettingsObject' = 'param($Enabled, $CategoryGroup)'
        'New-AzDiagnosticSetting'                  = 'param($Name, $ResourceId, $WorkspaceId, $Log)'
        'New-AzVirtualNetworkSubnetConfig'         = 'param($Name, $AddressPrefix)'
        'New-AzVirtualNetwork'                     = 'param($ResourceGroupName, $Name, $Location, $AddressPrefix, $Subnet, $Tag)'
        'New-AzNetworkInterface'                   = 'param($ResourceGroupName, $Name, $Location, $SubnetId, $Tag)'
        'New-AzVMConfig'                           = 'param($VMName, $VMSize)'
        'Set-AzVMOperatingSystem'                  = 'param($VM, [switch]$Linux, $ComputerName, $Credential, [switch]$DisablePasswordAuthentication)'
        'Add-AzVMSshPublicKey'                     = 'param($VM, $KeyData, $Path)'
        'Set-AzVMSourceImage'                      = 'param($VM, $PublisherName, $Offer, $Skus, $Version)'
        'Add-AzVMNetworkInterface'                 = 'param($VM, $Id)'
        'Set-AzVMOSDisk'                           = 'param($VM, $CreateOption, $StorageAccountType)'
        'New-AzVM'                                 = 'param($ResourceGroupName, $Location, $VM, $Tag)'
    }
    foreach ($n in $stubs.Keys) {
        # Always shadow: runners with Az installed would otherwise mock real cmdlets whose signatures differ by version.
        Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n]))
    }
    $script:StubNames = $stubs.Keys
    . $PSScriptRoot/../scripts/Start-DemoRun.ps1

    function script:Initialize-Mock {
        $script:Calls = [System.Collections.Generic.List[object]]::new()
        $script:out = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $script:Sub } } }
        Mock Get-DemoRunCostEstimate { $script:Calls.Add(@{ Cmd = 'cost' }); [pscustomobject]@{ TotalEur = 0.1; Lines = @(); PriceDate = '2026-11-01' } }
        Mock New-DemoSshKey { $script:Calls.Add(@{ Cmd = 'ssh' }); 'ssh-ed25519 AAAAFAKE demo' }
        Mock New-AzResourceGroup { $script:Calls.Add(@{ Cmd = 'New-AzResourceGroup'; Tag = $Tag }) }
        Mock New-AzOperationalInsightsWorkspace { $script:Calls.Add(@{ Cmd = 'New-AzOperationalInsightsWorkspace'; Tag = $Tag }); [pscustomobject]@{ ResourceId = "/subscriptions/$($script:Sub)/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log" } }
        Mock New-AzStorageAccount { $script:Calls.Add(@{ Cmd = 'New-AzStorageAccount'; Tag = $Tag }); [pscustomobject]@{ Id = "/subscriptions/$($script:Sub)/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st" } }
        Mock New-AzDiagnosticSettingLogSettingsObject { $script:Calls.Add(@{ Cmd = 'New-AzDiagnosticSettingLogSettingsObject' }); 'logobj' }
        Mock New-AzDiagnosticSetting { $script:Calls.Add(@{ Cmd = 'New-AzDiagnosticSetting'; Name = $Name }) }
        Mock New-AzVirtualNetworkSubnetConfig { $script:Calls.Add(@{ Cmd = 'New-AzVirtualNetworkSubnetConfig' }); 'subnetcfg' }
        Mock New-AzVirtualNetwork { $script:Calls.Add(@{ Cmd = 'New-AzVirtualNetwork'; Tag = $Tag }); [pscustomobject]@{ Subnets = @([pscustomobject]@{ Name = 'snet-app'; Id = 'snet-app-id' }) } }
        Mock New-AzNetworkInterface { $script:Calls.Add(@{ Cmd = 'New-AzNetworkInterface'; Tag = $Tag }); [pscustomobject]@{ Id = 'nic-id' } }
        Mock New-AzVMConfig { $script:Calls.Add(@{ Cmd = 'New-AzVMConfig' }); [pscustomobject]@{ Name = 'vmcfg' } }
        Mock Set-AzVMOperatingSystem { $script:Calls.Add(@{ Cmd = 'Set-AzVMOperatingSystem' }); $VM }
        Mock Add-AzVMSshPublicKey { $script:Calls.Add(@{ Cmd = 'Add-AzVMSshPublicKey' }); $VM }
        Mock Set-AzVMSourceImage { $script:Calls.Add(@{ Cmd = 'Set-AzVMSourceImage' }); $VM }
        Mock Add-AzVMNetworkInterface { $script:Calls.Add(@{ Cmd = 'Add-AzVMNetworkInterface' }); $VM }
        Mock Set-AzVMOSDisk { $script:Calls.Add(@{ Cmd = 'Set-AzVMOSDisk' }); $VM }
        Mock New-AzVM { $script:Calls.Add(@{ Cmd = 'New-AzVM'; Tag = $Tag }) }
    }
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

Describe 'Invoke-StartDemoRun' {
    BeforeEach { Initialize-Mock }

    It 'cost guard runs first and the setup calls follow the documented order' {
        $res = Invoke-StartDemoRun -RunId '202611181805' -Location swedencentral -OutDir $script:out 6>&1
        Write-Host ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $order = 'cost', 'New-AzResourceGroup', 'New-AzOperationalInsightsWorkspace', 'New-AzStorageAccount', 'New-AzDiagnosticSetting', 'New-AzVirtualNetwork', 'New-AzNetworkInterface', 'New-AzVM'
        $actual = @($script:Calls.Cmd | Where-Object { $_ -in $order })
        $actual | Should -Be $order
    }

    It 'passes the documented values to the Az cmdlets' {
        $null = Invoke-StartDemoRun -RunId '202611181805' -Location swedencentral -OutDir $script:out 6>&1
        Should -Invoke New-AzVMConfig -Times 1 -Exactly -ParameterFilter { $VMSize -eq 'Standard_B1s' -and $VMName -eq 'vm-traffic' }
        Should -Invoke Set-AzVMSourceImage -Times 1 -Exactly -ParameterFilter { $Offer -eq '0001-com-ubuntu-server-jammy' -and $Skus -eq '22_04-lts-gen2' -and $PublisherName -eq 'Canonical' }
        Should -Invoke Set-AzVMOperatingSystem -Times 1 -Exactly -ParameterFilter { $DisablePasswordAuthentication -and $Linux }
        Should -Invoke New-AzVirtualNetworkSubnetConfig -Times 1 -Exactly -ParameterFilter { $Name -eq 'snet-app' }
        Should -Invoke New-AzNetworkInterface -Times 1 -Exactly -ParameterFilter { $SubnetId -eq 'snet-app-id' -and $Name -eq 'vm-traffic-nic' }
        Should -Invoke New-AzDiagnosticSetting -Times 1 -Exactly -ParameterFilter { $Name -eq 'diag-to-log' -and $ResourceId -like '*/blobServices/default' -and $WorkspaceId -eq "/subscriptions/$($script:Sub)/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log" }
    }

    It 'failure after resource group leaves a run record' {
        Mock New-AzVM { throw 'vm quota exceeded' }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'Partial run: rg-gnp-202611181805 exists'
        $json = Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json
        $json.RunId | Should -Be '202611181805'
        $json.ResourceGroup | Should -Be 'rg-gnp-202611181805'
    }

    It 'over-budget estimate creates nothing' {
        Mock Get-DemoRunCostEstimate { [pscustomobject]@{ TotalEur = 5; Lines = @(); PriceDate = '2026-11-01' } }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
        Test-Path (Join-Path $script:out 'run.json') | Should -BeFalse
    }

    It 'stops before any change when there is no Az context' {
        Mock Get-AzContext { $null }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'Connect-AzAccount'
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
    }

    It 'every New-Az call that accepts -Tag carries the run tags' {
        $null = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        $tagged = @($script:Calls | Where-Object { $_.ContainsKey('Tag') })
        $tagged.Count | Should -Be 6
        foreach ($c in $tagged) {
            $c.Tag.project | Should -Be 'green-is-not-proof'
            $c.Tag.runId | Should -Be '202611181805'
        }
    }

    It 'run.json holds raw ids while console output is masked' {
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 0 -Because ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $json = Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json
        $json.WorkspaceId | Should -Match $script:Sub
        $json.RunId | Should -Be '202611181805'
        $json.ResourceGroup | Should -Be 'rg-gnp-202611181805'
        $json.StorageAccountName | Should -Be 'stgnp202611181805'
        $json.VnetName | Should -Be 'vnet-gnp'
        $json.RogueVmName | Should -Be 'vm-traffic'
        $json.Location | Should -Be 'swedencentral'
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Not -Match $script:Sub
        $text | Should -Match '<sub>'
    }

    It 'rejects a run id that is not 12 digits' {
        $res = Invoke-StartDemoRun -RunId 'bad' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
    }
}

Describe 'demo-manifest.psd1' {
    It 'lists code-declared names and omits the rogue VM' {
        $m = Import-PowerShellDataFile $PSScriptRoot/../config/demo-manifest.psd1
        $m.Names | Should -Contain 'rg-gnp-{runId}'
        $m.Names | Should -Contain 'diag-to-log'
        ($m.Names -join ' ') | Should -Not -Match 'vm-traffic'
    }
}

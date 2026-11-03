BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $stubs = @{
        'Get-AzContext'            = 'param()'
        'Get-AzVirtualNetwork'     = 'param($ResourceGroupName, $Name)'
        'New-AzNetworkInterface'   = 'param($ResourceGroupName, $Name, $Location, $SubnetId, $Tag)'
        'New-AzVMConfig'           = 'param($VMName, $VMSize)'
        'Set-AzVMOperatingSystem'  = 'param($VM, [switch]$Linux, $ComputerName, $Credential, [switch]$DisablePasswordAuthentication)'
        'Add-AzVMSshPublicKey'     = 'param($VM, $KeyData, $Path)'
        'Set-AzVMSourceImage'      = 'param($VM, $PublisherName, $Offer, $Skus, $Version)'
        'Set-AzVMBootDiagnostic'   = 'param($VM, [switch]$Disable)'
        'Add-AzVMNetworkInterface' = 'param($VM, $Id)'
        'Set-AzVMOSDisk'           = 'param($VM, $CreateOption, $StorageAccountType)'
        'New-AzVM'                 = 'param($ResourceGroupName, $Location, $VM, $Tag)'
        'New-AzResource'           = 'param($ResourceId, $Location, $Properties, $Tag, [switch]$Force)'
    }
    foreach ($n in $stubs.Keys) { Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n])) }
    $script:StubNames = $stubs.Keys
    . $PSScriptRoot/../scripts/New-RogueResource.ps1

    function script:Write-Run([hashtable]$Extra = @{}) {
        $run = @{ RunId = '202611181805'; SubscriptionId = $script:Sub; ResourceGroup = 'rg-gnp-202611181805'; Location = 'swedencentral'; VnetName = 'vnet-gnp' }
        foreach ($k in $Extra.Keys) { $run[$k] = $Extra[$k] }
        $run | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
    }
    function script:Initialize-Mock {
        $script:out = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:out
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $script:Sub } } }
        Mock Get-AzVirtualNetwork { [pscustomobject]@{ Subnets = @([pscustomobject]@{ Id = 'snet-app-id' }) } }
        Mock New-DemoSshKey { 'ssh-ed25519 AAAAFAKE demo' }
        Mock New-AzNetworkInterface { [pscustomobject]@{ Id = 'nic-id' } }
        Mock New-AzVMConfig { [pscustomobject]@{ Name = 'vmcfg' } }
        foreach ($c in 'Set-AzVMOperatingSystem', 'Add-AzVMSshPublicKey', 'Set-AzVMSourceImage', 'Set-AzVMBootDiagnostic', 'Add-AzVMNetworkInterface', 'Set-AzVMOSDisk') {
            Mock $c { $VM }
        }
        Mock New-AzVM { }
        Mock New-AzResource { }
    }
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

Describe 'Invoke-NewRogueResource' {
    BeforeEach { Initialize-Mock }

    It 'creates the VM and NIC in the run''s subnet with the run tags and records it' {
        Write-Run
        (Invoke-NewRogueResource -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 0
        Should -Invoke New-AzNetworkInterface -Times 1 -Exactly -ParameterFilter { $SubnetId -eq 'snet-app-id' -and $Name -eq 'vm-traffic-nic' -and $Tag.runId -eq '202611181805' }
        Should -Invoke New-AzVMConfig -Times 1 -Exactly -ParameterFilter { $VMSize -eq 'Standard_B2ts_v2' -and $VMName -eq 'vm-traffic' }
        Should -Invoke Set-AzVMBootDiagnostic -Times 1 -Exactly -ParameterFilter { $Disable }
        Should -Invoke New-AzVM -Times 1 -Exactly -ParameterFilter { $ResourceGroupName -eq 'rg-gnp-202611181805' -and $Tag.project -eq 'green-is-not-proof' }
        (Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json).RogueVmName | Should -Be 'vm-traffic'
    }

    It 'gives the VM an enabled auto-shutdown schedule 3 hours ahead in UTC, with the run tags' {
        Write-Run
        $now = [datetime]::new(2026, 11, 18, 18, 5, 0, [DateTimeKind]::Utc)
        (Invoke-NewRogueResource -OutDir $script:out -Now $now 6>&1 | Select-Object -Last 1) | Should -Be 0
        Should -Invoke New-AzResource -Times 1 -Exactly -ParameterFilter {
            $ResourceId -like '*/resourceGroups/rg-gnp-202611181805/providers/Microsoft.DevTestLab/schedules/shutdown-computevm-vm-traffic' -and
            $Properties.status -eq 'Enabled' -and $Properties.taskType -eq 'ComputeVmShutdownTask' -and
            $Properties.dailyRecurrence.time -eq '2105' -and $Properties.timeZoneId -eq 'UTC' -and
            $Properties.targetResourceId -like '*/providers/Microsoft.Compute/virtualMachines/vm-traffic' -and $Tag.runId -eq '202611181805'
        }
    }

    It 'a failed schedule returns 1 but keeps the VM recorded for teardown' {
        Write-Run
        Mock New-AzResource { throw 'Forbidden' }
        $out = @(Invoke-NewRogueResource -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        ($out | Out-String) | Should -Match 'auto-shutdown schedule was not'
        (Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json).RogueVmName | Should -Be 'vm-traffic'
    }

    It 'refuses without run.json and creates nothing' {
        $out = @(Invoke-NewRogueResource -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        ($out | Out-String) | Should -Match 'Start-DemoRun\.ps1 first'
        Should -Invoke New-AzVM -Times 0
    }

    It 'refuses a second rogue VM in the same run' {
        Write-Run @{ RogueVmName = 'vm-traffic' }
        (Invoke-NewRogueResource -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 1
        Should -Invoke New-AzNetworkInterface -Times 0
    }

    It 'refuses a run whose declared deployment did not finish' {
        Write-Run @{ VnetName = '' }
        $out = @(Invoke-NewRogueResource -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        ($out | Out-String) | Should -Match 'no VnetName'
    }

    It 'refuses another subscription and masks it' {
        Write-Run @{ SubscriptionId = [guid]::NewGuid().ToString() }
        $out = @(Invoke-NewRogueResource -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        ($out | Out-String) | Should -Match 'not the demo subscription'
        Should -Invoke Get-AzVirtualNetwork -Times 0
    }

    It 'a VM failure returns 1 and does not record the VM' {
        Write-Run
        Mock New-AzVM { throw 'SkuNotAvailable' }
        (Invoke-NewRogueResource -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 1
        (Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json).PSObject.Properties['RogueVmName'] | Should -BeNullOrEmpty
    }
}

BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $stubs = @{
        'Get-AzContext'              = 'param()'
        'Get-AzResource'             = 'param($ResourceGroupName, $TagName, $TagValue)'
        'Get-AzResourceGroup'        = 'param($Name)'
        'Remove-AzResourceGroup'     = 'param($Name, [switch]$Force)'
        'Get-AzDiagnosticSetting'    = 'param($ResourceId)'
        'Remove-AzDiagnosticSetting' = 'param($ResourceId, $Name)'
        'New-AzStorageAccount'       = 'param($ResourceGroupName, $Name, $Location, $SkuName, $Kind, $Tag)'
    }
    $script:StubNames = @($stubs.Keys)
    foreach ($n in $stubs.Keys) { Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n])) }
    . $PSScriptRoot/../scripts/Stop-DemoRun.ps1

    function script:Initialize-Mock {
        $script:out = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:out
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $script:Sub } } }
        $script:RgGone = $false
        Mock Get-AzResourceGroup { if ($script:RgGone) { throw 'ResourceGroupNotFound: Resource group could not be found.' }; [pscustomobject]@{ ResourceGroupName = 'rg-gnp-202611181805'; Location = 'swedencentral' } }
        Mock Get-DemoExpectedSubscriptionId { $script:Sub }
        Mock Remove-AzResourceGroup { $script:RgGone = $true }
        Mock Remove-DemoDiagnosticSetting { 0 }
        Mock Get-DemoDiagnosticSettingName { @() }
        Mock Get-AzResource { @() }
        Mock New-AzStorageAccount { [pscustomobject]@{ Id = 'x' } }
    }
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

Describe 'Invoke-StopDemoRun' {
    BeforeEach { Initialize-Mock }

    It 'Stop-DemoRun on partial run (no storage account) recreates it empty, sweeps it and deletes the group' {
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 0
        Should -Invoke Remove-AzResourceGroup -Times 1 -ParameterFilter { $Name -eq 'rg-gnp-202611181805' -and $Force }
        Should -Invoke New-AzStorageAccount -Times 1 -Exactly
        Should -Invoke Remove-DemoDiagnosticSetting -Times 5 -Exactly
    }

    It 'removes settings on resources and storage sub-services before deleting the group' {
        $id = "/subscriptions/$($script:Sub)/resourceGroups/rg-gnp-202611181805/providers/Microsoft.Storage/storageAccounts/stgnp202611181805"
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ Name = 'stgnp202611181805'; ResourceId = $id; ResourceType = 'Microsoft.Storage/storageAccounts' }) } else { @() } }
        $null = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1
        Should -Invoke Remove-DemoDiagnosticSetting -Times 1 -ParameterFilter { $ResourceId -eq $id }
        foreach ($s in 'blob', 'file', 'queue', 'table') {
            Should -Invoke Remove-DemoDiagnosticSetting -Times 1 -ParameterFilter { $ResourceId -eq "$id/${s}Services/default" }
        }
    }

    It 'a setting still listed after removal fails before deleting the group' {
        $id = "/subscriptions/$($script:Sub)/resourceGroups/rg-gnp-202611181805/providers/Microsoft.Storage/storageAccounts/stgnp202611181805"
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ Name = 'stgnp202611181805'; ResourceId = $id; ResourceType = 'Microsoft.Storage/storageAccounts' }) } else { @() } }
        Mock Remove-DemoDiagnosticSetting { 1 }
        Mock Get-DemoDiagnosticSettingName { if ($ResourceId -like '*/blobServices/default') { 'diag-to-log' } }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        $text = ($out | Out-String)
        $text | Should -Match 'still listed after removal'
        $text | Should -Match 'diag-to-log'
        $text | Should -Not -Match $script:Sub
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'reads every resource and storage sub-service back after removal' {
        $id = "/subscriptions/$($script:Sub)/resourceGroups/rg-gnp-202611181805/providers/Microsoft.Storage/storageAccounts/stgnp202611181805"
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ Name = 'stgnp202611181805'; ResourceId = $id; ResourceType = 'Microsoft.Storage/storageAccounts' }) } else { @() } }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 0
        Should -Invoke Get-DemoDiagnosticSettingName -Times 5 -Exactly
        ($out | Out-String) | Should -Match 'Listed again: no diagnostic settings remain on 5 resource'
    }

    It 'a failed read-back fails before deleting the group' {
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ ResourceId = '/r'; ResourceType = 'Microsoft.Network/virtualNetworks' }) } else { @() } }
        Mock Get-DemoDiagnosticSettingName { throw 'Forbidden' }
        (Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 1
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'the final message says what was checked and what was not' {
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 0
        ($out | Out-String) | Should -Match 'Resource group rg-gnp-202611181805 gone; no resources tagged runId=202611181805 in the subscription\. Not covered: untagged resources outside the group\.'
    }

    It 'list failure throws and leaves resource' {
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ ResourceId = '/r'; ResourceType = 'Microsoft.Network/virtualNetworks' }) } else { @() } }
        Mock Remove-DemoDiagnosticSetting { throw 'Forbidden' }
        $out = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1
        ($out | Select-Object -Last 1) | Should -Be 1
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'skips deletion when the group is gone and still runs the tag check' {
        $script:RgGone = $true
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 0
        Should -Invoke Remove-AzResourceGroup -Times 0
        Should -Invoke Get-AzResource -Times 1 -ParameterFilter { $TagName -eq 'runId' -and $TagValue -eq '202611181805' }
    }

    It 'leftover tagged resource fails' {
        $leftId = "/subscriptions/$($script:Sub)/resourceGroups/rg-other/providers/Microsoft.Network/publicIPAddresses/pip"
        Mock Get-AzResource { if ($TagName) { @([pscustomobject]@{ ResourceId = $leftId; Name = 'pip' }) } else { @() } }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        $text = ($out | Out-String)
        $text | Should -Match 'pip'
        $text | Should -Not -Match $script:Sub
        $text | Should -Match '<sub>'
    }

    It 'reads the run id from run.json and removes the file on success' {
        @{ RunId = '202611181805'; SubscriptionId = $script:Sub } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 0
        Test-Path (Join-Path $script:out 'run.json') | Should -BeFalse
    }

    It 'deletes the generated SSH key pair after a clean teardown' {
        foreach ($k in 'demo_key', 'demo_key.pub') { Set-Content (Join-Path $script:out $k) 'k' }
        (Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 0
        Test-Path (Join-Path $script:out 'demo_key') | Should -BeFalse
        Test-Path (Join-Path $script:out 'demo_key.pub') | Should -BeFalse
    }

    It 'keeps the SSH key pair when teardown fails' {
        foreach ($k in 'demo_key', 'demo_key.pub') { Set-Content (Join-Path $script:out $k) 'k' }
        Mock Remove-AzResourceGroup { }
        (Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 1
        Test-Path (Join-Path $script:out 'demo_key') | Should -BeTrue
    }

    It 'keeps run.json when its RunId differs' {
        @{ RunId = '202611190000' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        $null = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1
        Test-Path (Join-Path $script:out 'run.json') | Should -BeTrue
    }

    It 'keeps run.json and the SSH key pair of another run after a clean teardown' {
        @{ RunId = '202611190000' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        foreach ($k in 'demo_key', 'demo_key.pub') { Set-Content (Join-Path $script:out $k) 'k' }
        (Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 0
        foreach ($f in 'run.json', 'demo_key', 'demo_key.pub') { Test-Path (Join-Path $script:out $f) | Should -BeTrue -Because $f }
    }

    It 'keeps the pair and says so when the record is another run''s' {
        @{ RunId = '202611190000' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        foreach ($k in 'demo_key', 'demo_key.pub') { Set-Content (Join-Path $script:out $k) 'k' }
        $text = (Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Out-String)
        $text | Should -Match 'belongs to another run'
        $text | Should -Not -Match 'Deleted out/demo_key'
    }

    It 'removes the pair with the record when run.json belongs to the torn-down run' {
        @{ RunId = '202611181805'; SubscriptionId = $script:Sub } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        foreach ($k in 'demo_key', 'demo_key.pub') { Set-Content (Join-Path $script:out $k) 'k' }
        (Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 0
        foreach ($f in 'run.json', 'demo_key', 'demo_key.pub') { Test-Path (Join-Path $script:out $f) | Should -BeFalse -Because $f }
    }

    It 'missing group with the Az not-found message is treated as missing' {
        Mock Get-AzResourceGroup { throw 'Provided resource group does not exist.' }
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 0
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'post-delete check accepts the Az not-found message' {
        Mock Get-AzResourceGroup { if ($script:RgGone) { throw 'Provided resource group does not exist.' }; [pscustomobject]@{ ResourceGroupName = 'rg'; Location = 'swedencentral' } }
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 0
        Should -Invoke Remove-AzResourceGroup -Times 1
    }

    It 'group lookup failure stops teardown' {
        @{ RunId = '202611181805'; SubscriptionId = $script:Sub } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        Mock Get-AzResourceGroup { throw "AuthorizationFailed 403 on /subscriptions/$($script:Sub)" }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        ($out | Out-String) | Should -Not -Match $script:Sub
        Should -Invoke Remove-AzResourceGroup -Times 0
        Test-Path (Join-Path $script:out 'run.json') | Should -BeTrue
    }

    It 'group still present after delete fails' {
        Mock Remove-AzResourceGroup { }
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
    }

    It 'a false from Remove-AzResourceGroup fails' {
        Mock Remove-AzResourceGroup { $false }
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
    }

    It 'null Az context fails before any call' {
        Mock Get-AzContext { $null }
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
        Should -Invoke Get-AzResourceGroup -Times 0
    }

    It 'keeps run.json when the leftover check fails' {
        @{ RunId = '202611181805'; SubscriptionId = $script:Sub } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        Mock Get-AzResource { if ($TagName) { @([pscustomobject]@{ ResourceId = '/x'; Name = 'x' }) } else { @() } }
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
        Test-Path (Join-Path $script:out 'run.json') | Should -BeTrue
    }

    It 'refuses a run recorded under another subscription, calling nothing' {
        @{ RunId = '202611181805'; SubscriptionId = [guid]::NewGuid().ToString() } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        $text = ($out | Out-String)
        $text | Should -Match 'not the demo subscription'
        $text | Should -Not -Match $script:Sub
        Should -Invoke Get-AzResourceGroup -Times 0
        Should -Invoke Remove-AzResourceGroup -Times 0
        Test-Path (Join-Path $script:out 'run.json') | Should -BeTrue
    }

    It 'refuses a run.json that has no SubscriptionId' {
        @{ RunId = '202611181805' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        ($out | Out-String) | Should -Match 'no SubscriptionId'
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'with only -RunId, refuses when the configured subscription differs' {
        Mock Get-DemoExpectedSubscriptionId { [guid]::NewGuid().ToString() }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        Should -Invoke Remove-AzResourceGroup -Times 0
        Should -Invoke Get-AzResourceGroup -Times 0
    }

    It 'with only -RunId, refuses when nothing is configured' {
        Mock Get-DemoExpectedSubscriptionId { '' }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        ($out | Out-String) | Should -Match 'not configured'
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'does not read SubscriptionNotFound as a missing group' {
        Mock Get-AzResourceGroup { throw "SubscriptionNotFound: The subscription 'x' could not be found." }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        Should -Invoke Remove-AzResourceGroup -Times 0
        Should -Invoke Get-AzResource -Times 0
    }

    It 'recreates a missing storage account so its orphaned setting can be removed, then deletes the group' {
        @{ RunId = '202611181805'; SubscriptionId = $script:Sub; StorageAccountName = 'stgnp202611181805' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        # The group listing still lags after the create, as seen live: the new account's id comes from the create result.
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ Name = 'vnet-gnp'; ResourceId = '/v'; ResourceType = 'Microsoft.Network/virtualNetworks' }) } else { @() } }
        Mock New-AzStorageAccount { [pscustomobject]@{ Id = '/s' } }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 0
        ($out | Out-String) | Should -Match 'Storage stgnp202611181805 from this run is missing; recreating it empty'
        Should -Invoke New-AzStorageAccount -Times 1 -Exactly -ParameterFilter { $Name -eq 'stgnp202611181805' -and $ResourceGroupName -eq 'rg-gnp-202611181805' }
        Should -Invoke Remove-DemoDiagnosticSetting -Times 1 -ParameterFilter { $ResourceId -eq '/s' }
        Should -Invoke Remove-DemoDiagnosticSetting -Times 1 -ParameterFilter { $ResourceId -eq '/s/blobServices/default' }
        Should -Invoke Remove-AzResourceGroup -Times 1
    }

    It 'without run.json it recreates the fixed-name account when it is missing' {
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ Name = 'vnet-gnp'; ResourceId = '/v'; ResourceType = 'Microsoft.Network/virtualNetworks' }) } else { @() } }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 0
        Should -Invoke New-AzStorageAccount -Times 1 -Exactly -ParameterFilter { $Name -eq 'stgnp202611181805' }
    }

    It 'without run.json it does not recreate the account when it is in the group' {
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ Name = 'stgnp202611181805'; ResourceId = '/s'; ResourceType = 'Microsoft.Storage/storageAccounts' }) } else { @() } }
        $null = Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1
        Should -Invoke New-AzStorageAccount -Times 0 -Exactly
    }

    It 'retries while Azure holds the name, then gives up with exit 1 and keeps the group' {
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ Name = 'vnet-gnp'; ResourceId = '/v'; ResourceType = 'Microsoft.Network/virtualNetworks' }) } else { @() } }
        Mock New-AzStorageAccount { throw 'StorageAccountAlreadyTaken' }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        Should -Invoke New-AzStorageAccount -Times 13 -Exactly
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'any other create error stops the teardown before deleting the group' {
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ Name = 'vnet-gnp'; ResourceId = '/v'; ResourceType = 'Microsoft.Network/virtualNetworks' }) } else { @() } }
        Mock New-AzStorageAccount { throw 'Forbidden' }
        $out = @(Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        Should -Invoke New-AzStorageAccount -Times 1 -Exactly
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'goes on when the run''s storage account is in the group' {
        @{ RunId = '202611181805'; SubscriptionId = $script:Sub; StorageAccountName = 'stgnp202611181805' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ Name = 'STGNP202611181805'; ResourceId = '/s'; ResourceType = 'Microsoft.Storage/storageAccounts' }) } else { @() } }
        (Invoke-StopDemoRun -PollDelaySeconds 0 -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 0
        Should -Invoke Remove-AzResourceGroup -Times 1
    }

    It 'polls the tag query and accepts leftovers that disappear' {
        $script:polls = 0
        Mock Get-AzResource { if ($TagName) { $script:polls++; if ($script:polls -lt 3) { @([pscustomobject]@{ ResourceId = '/x'; Name = 'x' }) } else { @() } } else { @() } }
        (Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 0
        $script:polls | Should -Be 3
    }

    It 'polls six times before declaring leftovers' {
        Mock Get-AzResource { if ($TagName) { @([pscustomobject]@{ ResourceId = '/x'; Name = 'x' }) } else { @() } }
        (Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1) | Should -Be 1
        Should -Invoke Get-AzResource -Times 6 -Exactly -ParameterFilter { $TagName }
    }

    It 'an AuthorizationFailed message prints neither an e-mail address nor an object id' {
        $mail = 'a.b' + '@' + 'example.org'
        $oid = [guid]::NewGuid().ToString()
        Mock Get-AzResourceGroup { throw "AuthorizationFailed: client '$mail' with object id '$oid' on /subscriptions/$($script:Sub)" }
        $text = (Invoke-StopDemoRun -PollDelaySeconds 0 -RunId '202611181805' -OutDir $script:out 6>&1 | Out-String)
        $text | Should -Not -Match 'example\.org'
        $text | Should -Not -Match $oid
        $text | Should -Not -Match $script:Sub
        $text | Should -Match '<email>'
        $text | Should -Match '<guid>'
    }

    It 'fails when no run id is available' {
        $code = Invoke-StopDemoRun -PollDelaySeconds 0 -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
        Should -Invoke Remove-AzResourceGroup -Times 0
    }
}

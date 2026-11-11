BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $stubs = @{
        'Get-AzContext'      = 'param()'
        'Get-AzVMExtension'  = 'param($ResourceGroupName, $VMName, $Name)'
        'Set-AzVMExtension'  = 'param($ResourceGroupName, $VMName, $Location, $Name, $Publisher, $ExtensionType, $TypeHandlerVersion, $Settings)'
    }
    foreach ($n in $stubs.Keys) { Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n])) }
    $script:StubNames = $stubs.Keys
    . $PSScriptRoot/../demos/5-exists-is-not-healthy/New-FailedExtension.ps1
    . $PSScriptRoot/../demos/5-exists-is-not-healthy/Show-ExistenceVsState.ps1

    function script:Initialize-Mock([hashtable]$Run = @{}) {
        $script:out = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:out
        $r = @{ RunId = '202611181805'; SubscriptionId = $script:Sub; ResourceGroup = 'rg-gnp-202611181805'; Location = 'swedencentral'; RogueVmName = 'vm-traffic' }
        foreach ($k in $Run.Keys) { $r[$k] = $Run[$k] }
        $r | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $script:Sub } } }
        Mock Get-DemoExpectedSubscriptionId { $script:Sub }
        Mock Set-AzVMExtension { throw 'VMExtensionProvisioningError: exit status 1' }
        $script:State = 'Failed'
        Mock Get-AzVMExtension { [pscustomobject]@{ Name = 'gnp-failing-script'; ProvisioningState = $script:State } }
    }
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

Describe 'Get-ExtensionStateText' {
    It 'returns the state text' { Get-ExtensionStateText -Extension ([pscustomobject]@{ ProvisioningState = 'Failed' }) | Should -Be 'Failed' }
    It 'returns (missing) for <Name>' -ForEach @(
        @{ Name = 'no object'; Ext = $null }
        @{ Name = 'no property'; Ext = ([pscustomobject]@{ Other = 1 }) }
        @{ Name = 'a blank state'; Ext = ([pscustomobject]@{ ProvisioningState = '  ' }) }
    ) { Get-ExtensionStateText -Extension $Ext | Should -Be '(missing)' }
}

Describe 'Invoke-NewFailedExtension' {
    BeforeEach { Initialize-Mock }

    It 'adds the failing CustomScript extension to the run''s VM and returns 0 once it is Failed' {
        $res = Invoke-NewFailedExtension -OutDir $script:out -PollSeconds 0 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 0
        Should -Invoke Set-AzVMExtension -Times 1 -Exactly -ParameterFilter {
            $ResourceGroupName -eq 'rg-gnp-202611181805' -and $VMName -eq 'vm-traffic' -and $Name -eq 'gnp-failing-script' -and
            $ExtensionType -eq 'CustomScript' -and $Publisher -eq 'Microsoft.Azure.Extensions' -and $Settings.commandToExecute -eq 'exit 1'
        }
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'reached ProvisioningState Failed'
    }

    It 'returns 1 and says so when the extension ends Succeeded' {
        $script:State = 'Succeeded'
        $res = Invoke-NewFailedExtension -OutDir $script:out -PollSeconds 0 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'did not reach Failed \(state: Succeeded\)'
    }

    It 'returns 1 when the extension never shows up within the wait' {
        Mock Get-AzVMExtension { $null }
        $res = Invoke-NewFailedExtension -OutDir $script:out -WaitSeconds 0 -PollSeconds 0 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'state: \(missing\)'
    }

    It 'returns 1 for a run without a VM, creating nothing' {
        Initialize-Mock @{ RogueVmName = '' }
        $res = Invoke-NewFailedExtension -OutDir $script:out -PollSeconds 0 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'New-RogueResource'
        Should -Invoke Set-AzVMExtension -Times 0 -Exactly
    }

    It 'refuses another subscription before any change' {
        Mock Get-DemoExpectedSubscriptionId { [guid]::NewGuid().ToString() }
        Initialize-Mock @{ SubscriptionId = [guid]::NewGuid().ToString() }
        $res = Invoke-NewFailedExtension -OutDir $script:out -PollSeconds 0 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'not the demo subscription'
        Should -Invoke Set-AzVMExtension -Times 0 -Exactly
    }
}

Describe 'Invoke-ShowExistenceVsState' {
    BeforeEach { Initialize-Mock }

    It 'prints a passing existence check and a failing state check and returns 1 for a Failed extension' {
        $res = Invoke-ShowExistenceVsState -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Match 'Existence check: PASS'
        $text | Should -Match 'State check:     FAIL \(ProvisioningState: Failed\)'
        $text | Should -Match 'One read of this extension, in this configuration, at this moment\.'
    }

    It 'returns 0 for a Succeeded extension' {
        $script:State = 'Succeeded'
        $res = Invoke-ShowExistenceVsState -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 0
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'State check:     PASS'
    }

    It 'returns 1 for a state that is not Succeeded, such as <State>' -ForEach @(@{ State = 'Creating' }, @{ State = 'Updating' }, @{ State = 'Failed' }) {
        $script:State = $State
        (Invoke-ShowExistenceVsState -OutDir $script:out 6>&1 | Where-Object { $_ -is [int] }) | Should -Be 1
    }

    It 'with -ExpectFailed returns 0 for a Failed extension and prints the same lines' {
        $res = Invoke-ShowExistenceVsState -OutDir $script:out -ExpectFailed 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 0
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'State check:     FAIL \(ProvisioningState: Failed\)'
    }

    It 'with -ExpectFailed returns 1 and says it does not show the point when the state is <State>' -ForEach @(@{ State = 'Succeeded' }, @{ State = 'Creating' }) {
        $script:State = $State
        $res = Invoke-ShowExistenceVsState -OutDir $script:out -ExpectFailed 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'not Failed'
    }

    It 'never reads a missing state as a pass' {
        Mock Get-AzVMExtension { [pscustomobject]@{ Name = 'gnp-failing-script' } }
        $res = Invoke-ShowExistenceVsState -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Match 'State check:     FAIL \(ProvisioningState: \(missing\)\)'
        $text | Should -Not -Match 'State check:     PASS'
    }

    It 'returns 1 when the extension is not found' {
        Mock Get-AzVMExtension { $null }
        $res = Invoke-ShowExistenceVsState -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'Existence check: FAIL'
    }

    It 'returns 1 and says the check did not run when the read fails for another reason' {
        Mock Get-AzVMExtension { throw 'Unable to reach the management endpoint' }
        $res = Invoke-ShowExistenceVsState -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Match 'The check did not run'
        $text | Should -Not -Match 'Existence check: FAIL'
    }

    It 'reads <Name> as a check that did not run, not as a missing extension, <Mode>' -ForEach @(
        foreach ($mode in 'default', 'ExpectFailed') {
            foreach ($c in @(
                @{ Name = 'SubscriptionNotFound'; Msg = "SubscriptionNotFound: The subscription 'x' could not be found." }
                @{ Name = 'ResourceGroupNotFound'; Msg = "ResourceGroupNotFound: Resource group 'rg' could not be found." }
                @{ Name = 'a bare NotFound'; Msg = 'NotFound' }
                @{ Name = 'a VM not found'; Msg = "ResourceNotFound: The Resource 'Microsoft.Compute/virtualMachines/vm-traffic' under resource group 'rg' was not found." }
            )) { @{ Name = $c.Name; Msg = $c.Msg; Mode = $mode } }
        }
    ) {
        $m = $Msg
        Mock Get-AzVMExtension { throw $m }.GetNewClosure()
        $res = if ($Mode -eq 'ExpectFailed') { Invoke-ShowExistenceVsState -OutDir $script:out -ExpectFailed 6>&1 } else { Invoke-ShowExistenceVsState -OutDir $script:out 6>&1 }
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Match 'The check did not run'
        $text | Should -Not -Match 'New-FailedExtension'
        $text | Should -Not -Match 'Existence check: FAIL'
    }

    It 'reads an extension-specific ResourceNotFound as a missing extension, <Mode>' -ForEach @(@{ Mode = 'default' }, @{ Mode = 'ExpectFailed' }) {
        Mock Get-AzVMExtension { throw "ResourceNotFound: The Resource 'Microsoft.Compute/virtualMachines/vm-traffic/extensions/gnp-failing-script' under resource group 'rg' was not found." }
        $res = if ($Mode -eq 'ExpectFailed') { Invoke-ShowExistenceVsState -OutDir $script:out -ExpectFailed 6>&1 } else { Invoke-ShowExistenceVsState -OutDir $script:out 6>&1 }
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'Existence check: FAIL.*New-FailedExtension\.ps1'
    }

    It 'returns 1 and says the check did not run when there is no Azure context' {
        Mock Get-AzContext { $null }
        $res = Invoke-ShowExistenceVsState -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'The check did not run'
    }

    It 'returns 1 and says the check did not run when the run file is unusable' {
        Remove-Item (Join-Path $script:out 'run.json')
        $res = Invoke-ShowExistenceVsState -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'The check did not run'
    }

    It 'masks the subscription id' {
        Mock Get-AzVMExtension { [pscustomobject]@{ ProvisioningState = "Failed $($script:Sub)" } }
        $text = (Invoke-ShowExistenceVsState -OutDir $script:out 6>&1 | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Not -Match $script:Sub
        $text | Should -Match '<sub>'
    }
}

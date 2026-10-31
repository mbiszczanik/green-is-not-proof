BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $stubs = @{
        'Get-AzContext'                      = 'param()'
        'Get-AzOperationalInsightsWorkspace' = 'param($ResourceGroupName, $Name)'
    }
    foreach ($n in $stubs.Keys) {
        # Always shadow: runners with Az installed would otherwise mock real cmdlets with typed parameters.
        Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n]))
    }
    $script:StubNames = $stubs.Keys
    . $PSScriptRoot/../demos/3-stub-proves-assumption/Test-WorkspaceHealth.ps1
    . $PSScriptRoot/../demos/3-stub-proves-assumption/Show-LiveProperty.ps1

    function script:New-TestWorkspace([string]$State = 'Succeeded', $Prop = $null) {
        [pscustomobject]@{ ProvisioningState = $State; (Get-HealthPropertyName) = $Prop }
    }
    function script:Initialize-Mock([object]$Workspace) {
        $script:out = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:out
        @{ RunId = '202611181805'; SubscriptionId = $script:Sub; ResourceGroup = 'rg-gnp-202611181805'; Location = 'swedencentral' } |
            ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        $script:Ws = $Workspace
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $script:Sub } } }
        Mock Get-DemoExpectedSubscriptionId { $script:Sub }
        Mock Get-AzOperationalInsightsWorkspace { $script:Ws }
    }
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

Describe 'Test-WorkspaceHealth' {
    It 'Strict is true with the property filled' {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace -Prop @('x')) -Mode Strict | Should -BeTrue
    }
    It 'Strict is the default mode' {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace -Prop @('x')) | Should -BeTrue
        Test-WorkspaceHealth -Workspace (New-TestWorkspace) | Should -BeFalse
    }
    It 'Strict is false with the property null' {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace) -Mode Strict | Should -BeFalse
    }
    It 'Strict is false with the property an empty list' {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace -Prop @()) -Mode Strict | Should -BeFalse
    }
    It 'Strict is false when the state is not Succeeded' {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace -State 'Updating' -Prop @('x')) -Mode Strict | Should -BeFalse
    }
    It 'swapping the property name changes what Strict demands' {
        $ws = [pscustomobject]@{ ProvisioningState = 'Succeeded'; OtherProperty = @('x') }
        Test-WorkspaceHealth -Workspace $ws -Mode Strict | Should -BeFalse
        Mock Get-HealthPropertyName { 'OtherProperty' }
        Test-WorkspaceHealth -Workspace $ws -Mode Strict | Should -BeTrue
    }
    It 'Lenient is true with the property null' {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace) -Mode Lenient | Should -BeTrue
    }
    It 'Lenient is false for <state>' -ForEach @(@{ state = 'Failed' }, @{ state = 'Deleting' }) {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace -State $state -Prop @('x')) -Mode Lenient | Should -BeFalse
    }
}

Describe 'Invoke-ShowLiveProperty' {
    It 'prints (empty) and Strict False for a workspace whose property is null, masked' {
        Initialize-Mock (New-TestWorkspace)
        $res = Invoke-ShowLiveProperty -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 0
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Match "$(Get-HealthPropertyName): \(empty\)"
        $text | Should -Match 'Strict health: False'
        $text | Should -Match 'Lenient health: True'
        Should -Invoke Get-AzOperationalInsightsWorkspace -Times 1 -Exactly -ParameterFilter { $ResourceGroupName -eq 'rg-gnp-202611181805' -and $Name -eq 'log-gnp-202611181805' }
    }
    It 'masks the subscription id in a populated value' {
        Initialize-Mock (New-TestWorkspace -Prop @("/subscriptions/$($script:Sub)/x"))
        $res = Invoke-ShowLiveProperty -OutDir $script:out 6>&1
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Not -Match $script:Sub
        $text | Should -Match 'Strict health: True'
    }
    It 'refuses a different current subscription before any read' {
        Initialize-Mock (New-TestWorkspace)
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = [guid]::NewGuid().ToString() } } }
        $res = Invoke-ShowLiveProperty -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'not the demo subscription'
        Should -Invoke Get-AzOperationalInsightsWorkspace -Times 0 -Exactly
    }
    It 'returns 1 without run.json and without -RunId' {
        Initialize-Mock (New-TestWorkspace)
        Remove-Item (Join-Path $script:out 'run.json')
        $res = Invoke-ShowLiveProperty -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
    }
}

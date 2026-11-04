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
    It 'is true with the state Succeeded and the property filled' {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace -Prop @('x')) | Should -BeTrue
    }
    It 'is false with the property null' {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace) | Should -BeFalse
    }
    It 'is false with the property an empty list' {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace -Prop @()) | Should -BeFalse
    }
    It 'is false for the state <state>' -ForEach @(@{ state = 'Updating' }, @{ state = 'Failed' }, @{ state = 'Deleting' }, @{ state = '' }) {
        Test-WorkspaceHealth -Workspace (New-TestWorkspace -State $state -Prop @('x')) | Should -BeFalse
    }
    It 'is false when ProvisioningState is missing, never read as success' {
        Test-WorkspaceHealth -Workspace ([pscustomobject]@{ (Get-HealthPropertyName) = @('x') }) | Should -BeFalse
    }
    It 'is false for a null workspace' {
        Test-WorkspaceHealth -Workspace $null | Should -BeFalse
    }
    It 'swapping the property name changes what it demands' {
        $ws = [pscustomobject]@{ ProvisioningState = 'Succeeded'; OtherProperty = @('x') }
        Test-WorkspaceHealth -Workspace $ws | Should -BeFalse
        Mock Get-HealthPropertyName { 'OtherProperty' }
        Test-WorkspaceHealth -Workspace $ws | Should -BeTrue
    }
    It 'has no Lenient mode' {
        (Get-Command Test-WorkspaceHealth).Parameters.ContainsKey('Mode') | Should -BeFalse
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
        $text | Should -Match 'ProvisioningState: Succeeded'
        $text | Should -Not -Match 'Lenient'
        $text | Should -Match 'One read of this workspace, in this configuration, at this moment\.'
        Should -Invoke Get-AzOperationalInsightsWorkspace -Times 1 -Exactly -ParameterFilter { $ResourceGroupName -eq 'rg-gnp-202611181805' -and $Name -eq 'log-gnp-202611181805' }
    }
    It 'prints (missing) when the live object has no ProvisioningState' {
        Initialize-Mock ([pscustomobject]@{ (Get-HealthPropertyName) = @('x') })
        $res = Invoke-ShowLiveProperty -OutDir $script:out 6>&1
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Match 'ProvisioningState: \(missing\)'
        $text | Should -Match 'Strict health: False'
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
    It 'treats a run.json from another run as no record and reads the requested run' {
        Initialize-Mock (New-TestWorkspace)
        Mock Get-DemoExpectedSubscriptionId { $script:Sub }
        $res = Invoke-ShowLiveProperty -RunId '202611190000' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 0
        Should -Invoke Get-AzOperationalInsightsWorkspace -Times 1 -Exactly -ParameterFilter { $ResourceGroupName -eq 'rg-gnp-202611190000' -and $Name -eq 'log-gnp-202611190000' }
    }
    It 'returns 1 without run.json and without -RunId' {
        Initialize-Mock (New-TestWorkspace)
        Remove-Item (Join-Path $script:out 'run.json')
        $res = Invoke-ShowLiveProperty -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
    }
}

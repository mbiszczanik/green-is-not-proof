BeforeAll {
    . $PSScriptRoot/../lib/RunContext.ps1
}

Describe 'RunContext' {
    It 'run id from fixed date' {
        New-DemoRunId -Now ([datetime]'2026-11-18 18:05') | Should -Be '202611181805'
    }
    It 'resource group name' {
        Get-DemoResourceGroupName -RunId '202611181805' | Should -Be 'rg-gnp-202611181805'
    }
    It 'tags carry project and runId' {
        $t = Get-DemoTag -RunId '202611181805'
        $t.project | Should -Be 'green-is-not-proof'
        $t.runId | Should -Be '202611181805'
    }
}

Describe 'subscription pinning' {
    BeforeAll {
        $script:Sub = [guid]::NewGuid().ToString()
        $script:Other = [guid]::NewGuid().ToString()
        $script:SavedEnv = $env:GNP_SUBSCRIPTION_ID
    }
    BeforeEach { $env:GNP_SUBSCRIPTION_ID = $null }
    AfterAll { $env:GNP_SUBSCRIPTION_ID = $script:SavedEnv }

    It 'reads the expected id from the environment variable' {
        $env:GNP_SUBSCRIPTION_ID = $script:Sub
        Get-DemoExpectedSubscriptionId -ConfigPath (Join-Path $TestDrive 'none.txt') | Should -Be $script:Sub
    }
    It 'falls back to the first non-empty line of the file' {
        $f = Join-Path $TestDrive 'subscription.txt'
        Set-Content $f -Value "`n  $($script:Sub)  `nsecond"
        Get-DemoExpectedSubscriptionId -ConfigPath $f | Should -Be $script:Sub
    }
    It 'prefers the environment variable over the file' {
        $f = Join-Path $TestDrive 'subscription.txt'
        Set-Content $f -Value $script:Other
        $env:GNP_SUBSCRIPTION_ID = $script:Sub
        Get-DemoExpectedSubscriptionId -ConfigPath $f | Should -Be $script:Sub
    }
    It 'returns an empty string when nothing is configured' {
        Get-DemoExpectedSubscriptionId -ConfigPath (Join-Path $TestDrive 'none.txt') | Should -Be ''
    }
    It 'accepts the same id in another case' {
        { Assert-DemoSubscription -Expected $script:Sub.ToUpper() -Current $script:Sub } | Should -Not -Throw
    }
    It 'refuses a different subscription without printing either id' {
        $err = { Assert-DemoSubscription -Expected $script:Sub -Current $script:Other } | Should -Throw -PassThru
        $err.Exception.Message | Should -Be 'Current Azure subscription is not the demo subscription. Run Set-AzContext first.'
    }
    It 'refuses when no expected subscription is configured' {
        $err = { Assert-DemoSubscription -Expected '' -Current $script:Sub } | Should -Throw -PassThru
        $err.Exception.Message | Should -Be 'Expected demo subscription not configured (GNP_SUBSCRIPTION_ID or ~/.config/green-is-not-proof/subscription.txt).'
    }
    It 'run record without a SubscriptionId is refused' {
        $run = [pscustomobject]@{ RunId = '202611181805' }
        { Assert-DemoRunSubscription -Run $run -Current $script:Sub } | Should -Throw '*no SubscriptionId*'
    }
    It 'run record pins the subscription' {
        $run = [pscustomobject]@{ RunId = '202611181805'; SubscriptionId = $script:Sub }
        { Assert-DemoRunSubscription -Run $run -Current $script:Sub } | Should -Not -Throw
        { Assert-DemoRunSubscription -Run $run -Current $script:Other } | Should -Throw '*not the demo subscription*'
    }
    It 'without a run record the configured id is used' {
        $env:GNP_SUBSCRIPTION_ID = $script:Sub
        { Assert-DemoRunSubscription -Run $null -Current $script:Sub } | Should -Not -Throw
        { Assert-DemoRunSubscription -Run $null -Current $script:Other } | Should -Throw '*not the demo subscription*'
    }
}

Describe 'Read-DemoRun' {
    It 'returns the record when the run id matches or none is given' {
        @{ RunId = '202611181805' } | ConvertTo-Json | Set-Content (Join-Path $TestDrive 'run.json')
        (Read-DemoRun -OutDir $TestDrive).RunId | Should -Be '202611181805'
        (Read-DemoRun -OutDir $TestDrive -RunId '202611181805').RunId | Should -Be '202611181805'
    }
    It 'returns null for another run or no file' {
        @{ RunId = '202611181805' } | ConvertTo-Json | Set-Content (Join-Path $TestDrive 'run.json')
        Read-DemoRun -OutDir $TestDrive -RunId '202611190000' | Should -BeNullOrEmpty
        Read-DemoRun -OutDir (Join-Path $TestDrive 'nope') | Should -BeNullOrEmpty
    }
}

Describe 'Test-DemoResourceGroup' {
    BeforeAll { Set-Item function:global:Get-AzResourceGroup -Value ([scriptblock]::Create('param($Name)')) }
    AfterAll { Remove-Item function:global:Get-AzResourceGroup -ErrorAction SilentlyContinue }

    It 'is false for the documented not-found texts' {
        foreach ($m in 'ResourceGroupNotFound: x', "Resource group 'rg' could not be found.", 'Provided resource group does not exist.') {
            Mock Get-AzResourceGroup { throw $m }.GetNewClosure()
            Test-DemoResourceGroup -Name rg | Should -BeFalse
        }
    }
    It 'rethrows SubscriptionNotFound, a bare NotFound and other errors' {
        foreach ($m in "SubscriptionNotFound: The subscription 'x' could not be found.", 'NotFound', 'does not exist somewhere', 'Forbidden') {
            Mock Get-AzResourceGroup { throw $m }.GetNewClosure()
            { Test-DemoResourceGroup -Name rg } | Should -Throw
        }
    }
}

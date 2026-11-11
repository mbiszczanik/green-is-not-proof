BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Script = Join-Path $script:Root 'demos/5-exists-is-not-healthy/Show-ExistenceVsState.ps1'
    $script:Sub = [guid]::NewGuid().ToString()

    # Stub Az module found through PSModulePath, so the real script runs under pwsh -File with no Azure access.
    $mods = Join-Path $TestDrive 'modules'
    $mod = Join-Path $mods 'GnpAzStub'
    $null = New-Item -ItemType Directory -Path $mod
    Set-Content -Path (Join-Path $mod 'GnpAzStub.psm1') -Value @'
function Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $env:GNP_STUB_SUB } } }
function Get-AzVMExtension {
    param($ResourceGroupName, $VMName, $Name)
    if ($env:GNP_STUB_THROW) { throw $env:GNP_STUB_THROW }
    if ($env:GNP_STUB_MISSING) { return $null }
    [pscustomobject]@{ Name = $Name; ProvisioningState = $env:GNP_STUB_STATE }
}
'@
    New-ModuleManifest -Path (Join-Path $mod 'GnpAzStub.psd1') -RootModule 'GnpAzStub.psm1' -FunctionsToExport 'Get-AzContext', 'Get-AzVMExtension'
    $script:Mods = $mods

    $script:Out = Join-Path $TestDrive 'out'
    $null = New-Item -ItemType Directory -Path $script:Out
    @{ RunId = '202611181805'; SubscriptionId = $script:Sub; ResourceGroup = 'rg-gnp-202611181805'; Location = 'swedencentral'; RogueVmName = 'vm-traffic' } |
        ConvertTo-Json | Set-Content (Join-Path $script:Out 'run.json')

    function script:Invoke-Child([string]$State = '', [string]$Throw = '', [switch]$Missing, [switch]$ExpectFailed) {
        $saved = @{}
        $vars = @{ PSModulePath = ($script:Mods + [IO.Path]::PathSeparator + $env:PSModulePath); GNP_STUB_SUB = $script:Sub; GNP_STUB_STATE = $State; GNP_STUB_THROW = $Throw; GNP_STUB_MISSING = $(if ($Missing) { '1' } else { '' }) }
        foreach ($k in $vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
        try {
            $a = @('-NoProfile', '-File', $script:Script, '-OutDir', $script:Out)
            if ($ExpectFailed) { $a += '-ExpectFailed' }
            $text = (& $script:Pwsh @a 2>&1 | Out-String)
            [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
        }
        finally { foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) } }
    }
}

Describe 'Show-ExistenceVsState.ps1 process exit code (pwsh -File, stubbed Az)' {
    It 'exits 0 for a healthy extension without -ExpectFailed' {
        $r = Invoke-Child -State 'Succeeded'
        $r.Code | Should -Be 0 -Because $r.Text
        $r.Text | Should -Match 'State check:     PASS'
    }
    It 'exits 1 for a healthy extension with -ExpectFailed' {
        (Invoke-Child -State 'Succeeded' -ExpectFailed).Code | Should -Be 1
    }
    It 'exits 1 for a Failed extension without -ExpectFailed' {
        $r = Invoke-Child -State 'Failed'
        $r.Code | Should -Be 1 -Because $r.Text
        $r.Text | Should -Match 'State check:     FAIL'
    }
    It 'exits 0 for a Failed extension with -ExpectFailed' {
        $r = Invoke-Child -State 'Failed' -ExpectFailed
        $r.Code | Should -Be 0 -Because $r.Text
    }
    It 'exits 1 for a missing extension, <Mode>' -ForEach @(@{ Mode = 'default'; Flag = $false }, @{ Mode = 'ExpectFailed'; Flag = $true }) {
        $r = Invoke-Child -Missing -ExpectFailed:$Flag
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'Existence check: FAIL'
    }
    It 'exits 1 and says the check did not run for a subscription failure, <Mode>' -ForEach @(@{ Mode = 'default'; Flag = $false }, @{ Mode = 'ExpectFailed'; Flag = $true }) {
        $r = Invoke-Child -Throw "SubscriptionNotFound: The subscription 'x' could not be found." -ExpectFailed:$Flag
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'The check did not run'
        $r.Text | Should -Not -Match 'New-FailedExtension'
    }
}

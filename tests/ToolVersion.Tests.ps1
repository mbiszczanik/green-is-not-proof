BeforeAll {
    . $PSScriptRoot/../lib/ToolVersion.ps1
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Tools = Import-PowerShellDataFile -LiteralPath (Join-Path $script:Root 'config/demo-tools.psd1')
    $script:Match = [pscustomobject]@{ Name = 'PowerShell'; Actual = '7.6.9'; Observed = '7.6.9' }
    $script:Differs = [pscustomobject]@{ Name = 'Bicep CLI'; Actual = '0.39.1'; Observed = '0.38.5' }
    $script:Missing = [pscustomobject]@{ Name = 'PSRule'; Actual = ''; Observed = '2.9.0' }
    $script:Unrecorded = [pscustomobject]@{ Name = 'Pester'; Actual = '5.7.1'; Observed = '' }
}

Describe 'Format-DemoToolVersion' {
    It 'prints the versions and nothing else when every version is the observed one' {
        $lines = @(Format-DemoToolVersion -Tool @($script:Match, [pscustomobject]@{ Name = 'Bicep CLI'; Actual = '0.38.5'; Observed = '0.38.5' }))
        $lines.Count | Should -Be 1
        $lines[0] | Should -Be 'Tool versions: PowerShell 7.6.9; Bicep CLI 0.38.5'
    }

    It 'warns with both versions when a version differs from the observed one' {
        $lines = @(Format-DemoToolVersion -Tool @($script:Match, $script:Differs))
        $lines.Count | Should -Be 2
        $lines[1] | Should -Be "WARNING: Bicep CLI is 0.39.1; this demo's result was observed with Bicep CLI 0.38.5."
    }

    It 'warns when a tool with an observed version is not found' {
        $lines = @(Format-DemoToolVersion -Tool @($script:Missing))
        $lines[0] | Should -Be 'Tool versions: PSRule (not found)'
        $lines[1] | Should -Be "WARNING: PSRule was not found; this demo's result was observed with PSRule 2.9.0."
    }

    It 'names a tool without an observed version as not compared and does not warn about it' {
        $lines = @(Format-DemoToolVersion -Tool @($script:Match, $script:Unrecorded))
        $lines.Count | Should -Be 2
        $lines[1] | Should -Be 'Not compared, no observed version is recorded: Pester'
        ($lines -join "`n") | Should -Not -Match 'WARNING'
    }
}

Describe 'Get-DemoToolVersion' {
    BeforeAll {
        $script:Stub = Join-Path $TestDrive 'bicep-stub.ps1'
        Set-Content -LiteralPath $script:Stub -Value "'Bicep CLI version 0.38.5 (0123abcdef)'"
        $script:StubNewer = Join-Path $TestDrive 'bicep-stub-newer.ps1'
        Set-Content -LiteralPath $script:StubNewer -Value "'A new Bicep release is available: v0.99.1.'", "'Bicep CLI version 0.38.5 (0123abcdef)'"
        $script:StubSilent = Join-Path $TestDrive 'bicep-stub-silent.ps1'
        Set-Content -LiteralPath $script:StubSilent -Value "'no version here'"
    }

    It 'returns the version of the running PowerShell' {
        Get-DemoToolVersion -Name PowerShell | Should -Be $PSVersionTable.PSVersion.ToString()
    }

    It 'returns the version of a loaded module' {
        $loaded = Get-Module -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
        Get-DemoToolVersion -Name Pester | Should -Be $loaded.Version.ToString()
    }

    It 'returns an empty string for a module that is not installed' {
        Get-DemoToolVersion -Name 'Gnp.No.Such.Module' | Should -Be ''
    }

    It 'reads the Bicep CLI version from the tool output' {
        Get-DemoToolVersion -Name 'Bicep CLI' -BicepPath $script:Stub | Should -Be '0.38.5'
    }

    It 'does not take the version of a newer release the tool mentions' {
        Get-DemoToolVersion -Name 'Bicep CLI' -BicepPath $script:StubNewer | Should -Be '0.38.5'
    }

    It 'returns an empty string when the output holds no version' {
        Get-DemoToolVersion -Name 'Bicep CLI' -BicepPath $script:StubSilent | Should -Be ''
    }

    It 'returns an empty string when the Bicep CLI cannot be started' {
        Get-DemoToolVersion -Name 'Bicep CLI' -BicepPath (Join-Path $TestDrive 'no-such-bicep') | Should -Be ''
    }
}

Describe 'Write-DemoToolVersion' {
    BeforeAll {
        $script:Config = Join-Path $TestDrive 'tools.psd1'
        Set-Content -LiteralPath $script:Config -Value "@{ DemoX = @( @{ Name = 'PowerShell'; Observed = '7.6.9' }, @{ Name = 'Pester'; Observed = '' } ) }"
    }

    It 'prints the versions, the warning and the tools not compared, then an empty line' {
        Mock Get-DemoToolVersion { '7.5.0' } -ParameterFilter { $Name -eq 'PowerShell' }
        Mock Get-DemoToolVersion { '5.7.1' } -ParameterFilter { $Name -eq 'Pester' }
        $out = @(Write-DemoToolVersion -Demo DemoX -ConfigPath $script:Config 6>&1 | ForEach-Object { "$_" })
        $out.Count | Should -Be 4
        $out[0] | Should -Be 'Tool versions: PowerShell 7.5.0; Pester 5.7.1'
        $out[1] | Should -Be "WARNING: PowerShell is 7.5.0; this demo's result was observed with PowerShell 7.6.9."
        $out[2] | Should -Be 'Not compared, no observed version is recorded: Pester'
        $out[3] | Should -Be ''
    }

    It 'prints no warning when the version is the observed one' {
        Mock Get-DemoToolVersion { '7.6.9' } -ParameterFilter { $Name -eq 'PowerShell' }
        Mock Get-DemoToolVersion { '5.7.1' } -ParameterFilter { $Name -eq 'Pester' }
        $out = @(Write-DemoToolVersion -Demo DemoX -ConfigPath $script:Config 6>&1 | ForEach-Object { "$_" })
        ($out -join "`n") | Should -Not -Match 'WARNING'
    }

    It 'says so and does not throw when the demo has no entry' {
        { Write-DemoToolVersion -Demo DemoNone -ConfigPath $script:Config 6>$null } | Should -Not -Throw
        $out = @(Write-DemoToolVersion -Demo DemoNone -ConfigPath $script:Config 6>&1 | ForEach-Object { "$_" })
        $out[0] | Should -Match '^WARNING: tool versions could not be read'
    }

    It 'says so and does not throw when the tool list is missing' {
        $none = Join-Path $TestDrive 'none.psd1'
        { Write-DemoToolVersion -Demo DemoX -ConfigPath $none 6>$null } | Should -Not -Throw
        $out = @(Write-DemoToolVersion -Demo DemoX -ConfigPath $none 6>&1 | ForEach-Object { "$_" })
        $out[0] | Should -Match '^WARNING: tool versions could not be read'
    }
}

Describe 'config/demo-tools.psd1' {
    It 'gives every tool a name and an observed version that is empty or a version number' {
        $script:Tools.Keys.Count | Should -BeGreaterThan 0
        foreach ($demo in $script:Tools.Keys) {
            foreach ($entry in $script:Tools[$demo]) {
                $entry['Name'] | Should -Not -BeNullOrEmpty -Because "an entry of $demo"
                $entry.ContainsKey('Observed') | Should -BeTrue -Because "$demo, $($entry['Name'])"
                $entry['Observed'] | Should -Match '^(\d+\.\d+\.\d+)?$' -Because "$demo, $($entry['Name'])"
            }
        }
    }

    It 'has an entry for the tool list each demo entry point prints' {
        $entryPoints = @(
            'demos/0-tag-is-not-ownership/Invoke-TagAudit.ps1'
            'demos/0-tag-is-not-ownership/Invoke-OwnershipAudit.ps1'
            'demos/1-deleted-is-not-cleaned/Show-DiagnosticSettingLeftover.ps1'
            'demos/2-dry-run-is-not-safe/DryRun.Tests.ps1'
            'demos/3-stub-proves-assumption/Health.Stubbed.Tests.ps1'
            'demos/3-stub-proves-assumption/Show-LiveProperty.ps1'
            'demos/4-gate-never-red/Invoke-Gate.ps1'
            'demos/5-exists-is-not-healthy/New-FailedExtension.ps1'
            'demos/5-exists-is-not-healthy/Show-ExistenceVsState.ps1'
            'demos/6-lint-warns-gate-passes/Invoke-Gate.ps1'
            'demos/7-unprocessed-object-passes/Invoke-Gate.ps1'
        )
        foreach ($file in $entryPoints) {
            $text = Get-Content -LiteralPath (Join-Path $script:Root $file) -Raw
            $call = [regex]::Match($text, 'Write-DemoToolVersion -Demo (\w+)')
            $call.Success | Should -BeTrue -Because "$file shall print its tool versions"
            $script:Tools.ContainsKey($call.Groups[1].Value) | Should -BeTrue -Because "$file names $($call.Groups[1].Value)"
        }
    }
}

Describe 'Demo 4 runner' {
    It 'prints the tool versions before the validator output, and warns exactly when PowerShell is not the observed version' {
        $runner = Join-Path $script:Root 'demos/4-gate-never-red/Invoke-Gate.ps1'
        $out = @(& $script:Pwsh -NoProfile -File $runner -Script Fixed -State Ok 2>&1 | ForEach-Object { "$_" })
        $LASTEXITCODE | Should -Be 0
        $current = $PSVersionTable.PSVersion.ToString()
        $out[0] | Should -Match ('^Tool versions: PowerShell ' + [regex]::Escape($current) + '; Pester \d')
        $out | Should -Contain 'Not compared, no observed version is recorded: Pester'
        $observed = ($script:Tools['Demo4'] | Where-Object { $_['Name'] -eq 'PowerShell' })['Observed']
        $warning = "WARNING: PowerShell is $current; this demo's result was observed with PowerShell $observed."
        if ($current -eq $observed) { $out | Should -Not -Contain $warning } else { $out | Should -Contain $warning }
        [array]::IndexOf($out, 'Process exit code: 0') | Should -BeGreaterThan 0
    }
}

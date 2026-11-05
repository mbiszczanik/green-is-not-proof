BeforeDiscovery {
    $script:HasRules = [bool](Get-Module -ListAvailable PSRule.Rules.Azure)
}

BeforeAll {
    $script:Dir = Join-Path $PSScriptRoot '../demos/7-unprocessed-object-passes'
    $script:Runner = Join-Path $script:Dir 'Invoke-Gate.ps1'
    . $script:Runner -Gate Bare
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Zero = @('    [WARN] Target object ''x.bicep'' has not been processed because no matching rules were found.', 'Rules processed: 0, failed: 0, errored: 0')
    $script:Some = @('Rules processed: 21, failed: 0, errored: 0')
    $script:Errored = @('Rules processed: 3, failed: 0, errored: 1')
}

Describe 'Get-PSRuleSummary' {
    It 'reads the three counts' {
        $s = Get-PSRuleSummary -Line @('noise', 'Rules processed: 21, failed: 8, errored: 2')
        $s.Processed | Should -Be 21
        $s.Failed | Should -Be 8
        $s.Errored | Should -Be 2
    }

    It 'returns nothing when no summary line was printed' {
        Get-PSRuleSummary -Line @('[WARN] something') | Should -BeNullOrEmpty
        Get-PSRuleSummary -Line @() | Should -BeNullOrEmpty
    }
}

Describe 'Test-PSRuleGate' {
    It 'Bare passes on exit 0 although no rule was evaluated' {
        Test-PSRuleGate -Gate Bare -ExitCode 0 -Line $script:Zero | Should -BeTrue
    }

    It 'Fixed fails on exit 0 when zero rules were evaluated' {
        Test-PSRuleGate -Gate Fixed -ExitCode 0 -Line $script:Zero | Should -BeFalse -Because 'a fixed gate that passes while nothing was evaluated would show a pass it did not earn'
    }

    It 'Fixed fails on exit 0 when PSRule printed no summary' {
        Test-PSRuleGate -Gate Fixed -ExitCode 0 -Line @('[WARN] x') | Should -BeFalse
        Test-PSRuleGate -Gate Fixed -ExitCode 0 -Line @() | Should -BeFalse
    }

    It 'Fixed fails on exit 0 when a rule errored' {
        Test-PSRuleGate -Gate Fixed -ExitCode 0 -Line $script:Errored | Should -BeFalse
    }

    It 'both gates pass on exit 0 when rules were evaluated and none failed' {
        Test-PSRuleGate -Gate Bare -ExitCode 0 -Line $script:Some | Should -BeTrue
        Test-PSRuleGate -Gate Fixed -ExitCode 0 -Line $script:Some | Should -BeTrue
    }

    It 'both gates fail on a non-zero exit code' {
        Test-PSRuleGate -Gate Bare -ExitCode 1 -Line $script:Some | Should -BeFalse
        Test-PSRuleGate -Gate Fixed -ExitCode 1 -Line $script:Some | Should -BeFalse
    }
}

Describe 'Hide-LocalPath' {
    It 'replaces the demo folder in both slash styles' {
        $f = [IO.Path]::GetFullPath($script:Dir)
        (Hide-LocalPath -Text "a $f\Storage.bicep b" -Folder $f) | Should -Be 'a .\Storage.bicep b'
        (Hide-LocalPath -Text "a $($f.Replace('\', '/'))/Storage.bicep b" -Folder $f) | Should -Be 'a ./Storage.bicep b'
    }
}

Describe 'Invoke-PSRuleChild.ps1' {
    It 'exits 1 and says so when PSRule.Rules.Azure is not installed' -Skip:$script:HasRules {
        $out = @(& $script:Pwsh -NoProfile -File (Join-Path $script:Dir 'Invoke-PSRuleChild.ps1') -Path (Join-Path $script:Dir 'Storage.bicep') -ExpandBicep Off 2>&1 | ForEach-Object { "$_" })
        $LASTEXITCODE | Should -Be 1
        ($out -join "`n") | Should -Match 'not installed'
    }
}

Describe 'Invoke-Gate.ps1 with the real rules' {
    BeforeAll {
        function script:Invoke-GateProcess {
            param([string]$Gate, [string]$Pipeline)
            $out = @(& $script:Pwsh -NoProfile -File $script:Runner -Gate $Gate -Pipeline $Pipeline 2>&1 | ForEach-Object { "$_" })
            [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($out -join "`n") }
        }
    }

    It 'Bare passes on the misconfigured pipeline and says nothing was evaluated' -Skip:(-not $script:HasRules) {
        $r = Invoke-GateProcess -Gate Bare -Pipeline Misconfigured
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'Rules evaluated: 0'
        $r.Output | Should -Match 'would PASS although no rule was evaluated'
    }

    It 'Fixed fails on the misconfigured pipeline' -Skip:(-not $script:HasRules) {
        $r = Invoke-GateProcess -Gate Fixed -Pipeline Misconfigured
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'Fixed gate: FAIL'
    }
}

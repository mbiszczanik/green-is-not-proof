BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/zero-tests-pass'
    $script:Success = 'All discovered tests passed\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-Line([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern } |
                ForEach-Object { $_.Trim() })
    }
}

Describe 'gallery: a test run that discovers zero tests and reports success (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although zero tests were discovered' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match 'Discovered 0 test files\.'
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 prints the failure and exits 1 for the same empty discovery' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match 'Discovered 0 test files\.'
        $r.Text | Should -Match '\[FAIL\] no test files were discovered'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants run the same discovery' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $rx = '^\$testDir = |^\$found = '
        $before = @(Get-Line 'before.ps1' $rx)
        $after = @(Get-Line 'after.ps1' $rx)
        $before.Count | Should -Be 2
        $after.Count | Should -Be 2
        $after[0] | Should -BeExactly $before[0]
        $after[1] | Should -BeExactly $before[1]
        $before[0] | Should -Match 'GetTempPath\(\)'
    }
    It 'before.ps1 never checks the count' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw |
            Should -Not -Match '\bexit\b|\bthrow\b|\btry\b|\bif\b|\$found\.Count\s*-|\$\?|ErrorActionPreference'
    }
}

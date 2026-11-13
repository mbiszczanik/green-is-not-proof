BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/mock-cannot-fail'
    $script:Success = 'All tests passed: 1 passed\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-Line([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern } |
                ForEach-Object { $_.Trim() })
    }
}

Describe 'gallery: a mock that can never fail (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although the code ignores the dependency' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 turns the canary red, prints the failure and exits 1' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] .*canary: rejects a corrupt backup'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants run the same code under test' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $rx = '^\s*function '
        $before = @(Get-Line 'before.ps1' $rx)
        $after = @(Get-Line 'after.ps1' $rx)
        $before.Count | Should -Be 2
        $after.Count | Should -Be 2
        for ($i = 0; $i -lt 2; $i++) { $after[$i] | Should -BeExactly $before[$i] }
    }
    It 'the mock of before.ps1 has no input filter and no failing answer' {
        $mocks = @(Get-Line 'before.ps1' '^\s*Mock ')
        $mocks.Count | Should -Be 1
        $mocks[0] | Should -Not -Match 'ParameterFilter|Failed|throw'
    }
    It 'after.ps1 mocks a Failed answer for the bad input and tests that input' {
        $text = Get-Content -LiteralPath (Join-Path $script:Dir 'after.ps1') -Raw
        $text | Should -Match "Status = 'Failed' \} \} -ParameterFilter \{ \`$Name -eq 'vault-corrupt' \}"
        $text | Should -Match "Confirm-Backup 'vault-corrupt' \| Should -BeFalse"
    }
}

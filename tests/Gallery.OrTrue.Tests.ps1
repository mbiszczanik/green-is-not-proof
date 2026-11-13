BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/or-true-swallows-failure'
    $script:Success = 'Step complete: deploy step finished\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-StepLine([string]$Name) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match '^& \$pwsh ' } |
                ForEach-Object { $_.Trim() })
    }
}

Describe 'gallery: a failing step followed by || $true (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although the step failed' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match '\[FAIL\] deploy step'
        $r.Text | Should -Match '(?m)^True\s*$' -Because 'the README says the right-hand side prints its value'
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match 'failed with exit code'
    }
    It 'after.ps1 prints the failure and exits 1 for the same step' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] deploy step'
        $r.Text | Should -Match 'Deploy step failed with exit code 1\.'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants run the same step apart from || $true' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-StepLine 'before.ps1')
        $after = @(Get-StepLine 'after.ps1')
        $before.Count | Should -Be 1
        $after.Count | Should -Be 1
        $before[0] | Should -BeExactly ($after[0] + ' || $true')
        $after[0] | Should -Match 'exit 1'
    }
    It 'before.ps1 never reads the exit code' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw |
            Should -Not -Match 'LASTEXITCODE|\bexit \$|\bthrow\b|\bif\b|\$\?'
    }
}

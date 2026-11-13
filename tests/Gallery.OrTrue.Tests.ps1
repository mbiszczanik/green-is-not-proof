BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/or-true-swallows-failure'
    $script:Success = 'Step complete: build finished\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-StepLine([string]$Name) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match '^\s*& \$pwshPath ' } |
                ForEach-Object { $_.Trim() })
    }
}

Describe 'gallery: a failing step followed by || $true (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although the step failed' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 prints the failure and exits 1 for the same step' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] the step exited with code 1'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants run the same step apart from || $true' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-StepLine 'before.ps1')
        $after = @(Get-StepLine 'after.ps1')
        $before.Count | Should -Be 1
        $after.Count | Should -Be 1
        $before[0] | Should -Match ' \|\| \$true$'
        $after[0] | Should -BeExactly ($before[0] -replace ' \|\| \$true$', '')
    }
    It 'before.ps1 never checks the result' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw |
            Should -Not -Match '\bexit \$|\bthrow\b|\btry\b|\bif\b|\$\?|\$LASTEXITCODE|\$Error\b|ErrorActionPreference'
    }
}

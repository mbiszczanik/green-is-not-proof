BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/pipe-swallows-exit-code'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-InnerLine([string]$Name) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match '\| Tee-Object' })
    }
}

Describe 'gallery: exit code swallowed by a pipe (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 although its output shows the failure' {
        $r = Invoke-Variant 'before.ps1'
        $r.Text | Should -Match '\[FAIL\] inner check'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
    }
    It 'after.ps1 exits 1 for the same failure' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] inner check'
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants run the same inner command through the same pipe' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-InnerLine 'before.ps1')
        $after = @(Get-InnerLine 'after.ps1')
        $before.Count | Should -Be 1
        $after.Count | Should -Be 1
        $after[0] | Should -BeExactly $before[0]
        $before[0] | Should -Match 'exit 1'
    }
    It 'before.ps1 never reads LASTEXITCODE' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw | Should -Not -Match 'LASTEXITCODE'
    }
    It 'after.ps1 reads LASTEXITCODE straight after the pipeline' {
        $code = @(Get-Content -LiteralPath (Join-Path $script:Dir 'after.ps1') | Where-Object { $_.Trim() -and $_ -notmatch '^\s*#' })
        $i = [Array]::FindIndex([string[]]$code, [Predicate[string]] { param($l) $l -match '\| Tee-Object' })
        $i | Should -BeGreaterOrEqual 0
        $code[$i + 1] | Should -Match '=\s*\$LASTEXITCODE\s*$'
    }
}

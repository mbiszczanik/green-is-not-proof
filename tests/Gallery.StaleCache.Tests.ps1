BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/stale-cached-result'
    $script:Success = 'Check passed: the result file says passed\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-MatchingLine([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern })
    }
}

Describe 'gallery: a cached result read as if it were fresh (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although the result is two days old' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 prints the age of the result and exits 1 for the same file' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] The result file is 48 hours old \(limit 24 hours\)'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants hold the same <What>' -ForEach @(
        @{ What = 'file path'; Pattern = '^\$path = ' }
        @{ What = 'timestamp of the earlier run'; Pattern = 'LastWriteTimeUtc = ' }
        @{ What = 'read of the result'; Pattern = '^\$result = ' }
        @{ What = 'status check'; Pattern = '^if \(\$result\.status -eq ' }
    ) {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-MatchingLine 'before.ps1' $Pattern)
        $after = @(Get-MatchingLine 'after.ps1' $Pattern)
        $before.Count | Should -Be 1
        $after.Count | Should -Be 1
        $after[0] | Should -BeExactly $before[0]
    }
    It 'before.ps1 never compares the age of the result with a limit' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw | Should -Not -Match 'TotalHours|limitHours|-ge |-gt |-lt |-le '
    }
}

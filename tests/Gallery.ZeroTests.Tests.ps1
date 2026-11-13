BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/zero-tests-pass'
    $script:Success = 'All tests passed\.'
    $script:Count = 'Tests discovered: 0, failed: 0'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-MatchingLine([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern })
    }
}

Describe 'gallery: a test run that discovers zero tests (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although no test ran' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match $script:Count
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 prints the failure and exits 1 for the same empty folder' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match $script:Count
        $r.Text | Should -Match '\[FAIL\] No test was discovered'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants discover tests the same way in the same folder' -ForEach @(
        @{ What = 'folder'; Pattern = '^\$folder = ' }
        @{ What = 'discovery'; Pattern = '^\$tests = ' }
    ) {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-MatchingLine 'before.ps1' $Pattern)
        $after = @(Get-MatchingLine 'after.ps1' $Pattern)
        $before.Count | Should -Be 1
        $after.Count | Should -Be 1
        $after[0] | Should -BeExactly $before[0]
    }
    It 'before.ps1 never checks how many tests it discovered' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw | Should -Not -Match 'Count -(eq|lt|le|gt|ge|ne)'
    }
}

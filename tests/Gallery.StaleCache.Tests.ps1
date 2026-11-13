BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/stale-cached-result'
    $script:Success = 'Check passed: the last run reported ok\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-Line([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern } |
                ForEach-Object { $_.Trim() })
    }
    $script:Setup = '^\$resultDir = |^\$resultFile = |^New-Item |^Set-Content |LastWriteTimeUtc = |^\$maxAge = |^Write-Host "Freshness|^\$status = '
}

Describe 'gallery: a cached result read as if it were fresh (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although the result is two days old' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 compares the timestamp with the limit, prints the failure and exits 1' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] the result is 48 hours old, the limit is 1 hour'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants write the same stale file and run the same status check' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-Line 'before.ps1' $script:Setup)
        $after = @(Get-Line 'after.ps1' $script:Setup)
        $before.Count | Should -Be 8
        $after.Count | Should -Be 8
        for ($i = 0; $i -lt 8; $i++) { $after[$i] | Should -BeExactly $before[$i] }
        $before[0] | Should -Match 'GetTempPath\(\)'
        ($before -join "`n") | Should -Match 'AddDays\(-2\)'
    }
    It 'before.ps1 never looks at the age' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw |
            Should -Not -Match '\bexit\b|\bthrow\b|\$age\b|\$maxAge\s*-|-gt \$maxAge|-lt \$maxAge|ErrorActionPreference'
    }
}

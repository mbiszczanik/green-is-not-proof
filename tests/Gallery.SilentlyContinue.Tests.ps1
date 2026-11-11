BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/erroraction-silentlycontinue'
    $script:Success = 'Step complete: input file checked\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-CallLine([string]$Name) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match '^\s*Get-Item ' } |
                ForEach-Object { $_.Trim() })
    }
}

Describe 'gallery: -ErrorAction SilentlyContinue hides a failure (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although Get-Item failed' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]|Cannot find path|Found '
    }
    It 'after.ps1 prints the failure and exits 1 for the same call' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] .*gallery-erroraction-silentlycontinue-missing'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants make the same call apart from the -ErrorAction value' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-CallLine 'before.ps1')
        $after = @(Get-CallLine 'after.ps1')
        $before.Count | Should -Be 1
        $after.Count | Should -Be 1
        $before[0] | Should -Match '-ErrorAction SilentlyContinue\b'
        $after[0] | Should -BeExactly ($before[0] -replace '-ErrorAction SilentlyContinue\b', '-ErrorAction Stop')
    }
    It 'both variants ask for the same missing path' {
        $rx = '^\$path = '
        $before = @(Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') | Where-Object { $_ -match $rx })
        $after = @(Get-Content -LiteralPath (Join-Path $script:Dir 'after.ps1') | Where-Object { $_ -match $rx })
        $before.Count | Should -Be 1
        $after[0] | Should -BeExactly $before[0]
        $before[0] | Should -Match 'GetTempPath\(\)'
    }
    It 'before.ps1 never checks the result' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw |
            Should -Not -Match '\bexit\b|\bthrow\b|\btry\b|\bif\b|\$\?|\$Error\b|ErrorVariable|ErrorActionPreference'
    }
}

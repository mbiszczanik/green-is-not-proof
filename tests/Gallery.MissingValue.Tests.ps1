BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/comparator-accepts-missing'
    $script:Success = 'Check passed: latency is within the limit of 200 ms\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-Line([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern } |
                ForEach-Object { $_.Trim() })
    }
}

Describe 'gallery: a comparator that accepts a missing value (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although the value is missing' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 says the value was missing, prints the failure and exits 1' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] the value latencyMs was missing'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants read the same missing value and make the same comparison' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $rx = '^\$limit = |^\$reading = |^\$actual = |^if \(\$actual -le '
        $before = @(Get-Line 'before.ps1' $rx)
        $after = @(Get-Line 'after.ps1' $rx)
        $before.Count | Should -Be 4
        $after.Count | Should -Be 4
        for ($i = 0; $i -lt 4; $i++) { $after[$i] | Should -BeExactly $before[$i] }
        $before[2] | Should -Match "\['latencyMs'\]"
        $before[1] | Should -Not -Match 'latencyMs'
    }
    It 'before.ps1 never tests for the missing value' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw |
            Should -Not -Match '\bexit\b|\bthrow\b|\$null -eq|-eq \$null|ContainsKey|ErrorActionPreference'
    }
}

BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/empty-result-is-success'
    $script:Success = 'Check passed: no non-compliant resources found\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-Line([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern } |
                ForEach-Object { $_.Trim() })
    }
}

Describe 'gallery: an empty result read as success (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although the read returned nothing' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 says the read returned nothing, prints the failure and exits 1' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] the read returned nothing'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants use the same stub and the same filter' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $rx = '^function Get-Finding|^\$findings = |^\$bad = '
        $before = @(Get-Line 'before.ps1' $rx)
        $after = @(Get-Line 'after.ps1' $rx)
        $before.Count | Should -Be 3
        $after.Count | Should -Be 3
        for ($i = 0; $i -lt 3; $i++) { $after[$i] | Should -BeExactly $before[$i] }
        $before[0] | Should -Match '\{ @\(\) \}$'
    }
    It 'before.ps1 never tests for an empty list' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw |
            Should -Not -Match '\bexit\b|\bthrow\b|\$findings\.Count|-eq 0\) \{\s*Write-Host ''\[FAIL|ErrorActionPreference'
    }
}

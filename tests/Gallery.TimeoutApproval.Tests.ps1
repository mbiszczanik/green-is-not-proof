BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/timeout-as-approval'
    $script:Success = 'Approval wait finished\. Proceeding with the change\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-MatchingLine([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern })
    }
}

Describe 'gallery: a timeout read as approval (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although no answer arrived' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 says no answer arrived and exits 1 for the same wait' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match '\[FAIL\] No answer arrived within 2 seconds'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants hold the same <What>' -ForEach @(
        @{ What = 'answer file'; Pattern = '^\$answer = ' }
        @{ What = 'time limit'; Pattern = '^\$limitSeconds = ' }
        @{ What = 'wait loop'; Pattern = '^while \(' }
    ) {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-MatchingLine 'before.ps1' $Pattern)
        $after = @(Get-MatchingLine 'after.ps1' $Pattern)
        $before.Count | Should -Be 1
        $after.Count | Should -Be 1
        $after[0] | Should -BeExactly $before[0]
    }
    It 'before.ps1 never looks at why the loop ended' {
        $text = Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw
        @([regex]::Matches($text, 'Test-Path')).Count | Should -Be 1 -Because 'the only look at the answer file is the loop condition'
        $text | Should -Not -Match '\bif\b|\bexit\b|\bthrow\b'
    }
}

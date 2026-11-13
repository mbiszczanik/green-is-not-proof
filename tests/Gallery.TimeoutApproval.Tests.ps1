BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/timeout-as-approval'
    $script:Success = 'Step complete: change approved and applied\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-Line([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern } |
                ForEach-Object { $_.Trim() })
    }
    $script:Loop = '^\$approvalFile = |^\s*if \(Test-Path|^\$approved = |^\$deadline = |^while |Start-Sleep|^Write-Host "Waited'
}

Describe 'gallery: a timeout read as approval (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although no answer arrived' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match 'Waited for approval \(answered: False\)\.'
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 says no answer arrived, prints the failure and exits 1' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match 'Waited for approval \(answered: False\)\.'
        $r.Text | Should -Match '\[FAIL\] no answer arrived'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants run the same wait loop' {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-Line 'before.ps1' $script:Loop)
        $after = @(Get-Line 'after.ps1' $script:Loop)
        $before.Count | Should -Be 8
        $after.Count | Should -Be 8
        for ($i = 0; $i -lt 8; $i++) { $after[$i] | Should -BeExactly $before[$i] }
        $before[0] | Should -Match 'GetTempPath\(\)'
    }
    It 'before.ps1 never acts on the answer' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw |
            Should -Not -Match '\bexit\b|\bthrow\b|-not \$approved|\$approved -eq|if \(\$approved|ErrorActionPreference'
    }
}

BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Dir = Join-Path $script:Root 'gallery/mock-cannot-fail'
    $script:Success = 'All tests passed\.'

    function script:Invoke-Variant([string]$Name) {
        $text = (& $script:Pwsh -NoProfile -File (Join-Path $script:Dir $Name) 2>&1 | Out-String)
        [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    function script:Get-MatchingLine([string]$Name, [string]$Pattern) {
        @(Get-Content -LiteralPath (Join-Path $script:Dir $Name) | Where-Object { $_ -match $Pattern } | ForEach-Object { $_.Trim() })
    }
}

Describe 'gallery: a mock that can never fail (pwsh -File, child processes)' {
    It 'before.ps1 exits 0 and prints the success line although the function is defective' {
        $r = Invoke-Variant 'before.ps1'
        $r.Code | Should -Be 0 -Because "the before variant must keep hiding the failure; output: $($r.Text)"
        $r.Text | Should -Match 'Tests passed: 1, failed: 0'
        $r.Text | Should -Match $script:Success
        $r.Text | Should -Not -Match '\[FAIL\]'
    }
    It 'after.ps1 names the canary test as failed and exits 1 for the same function' {
        $r = Invoke-Variant 'after.ps1'
        $r.Text | Should -Match 'Tests passed: 1, failed: 1'
        $r.Text | Should -Match '\[FAIL\] is false for the canary, a deployment that failed'
        $r.Text | Should -Not -Match $script:Success
        $r.Code | Should -Be 1 -Because $r.Text
    }
    It 'both variants hold the same <What>' -ForEach @(
        @{ What = 'read of the state'; Pattern = '^\s*\$state = Get-DeploymentState ' }
        @{ What = 'defective result line'; Pattern = '^\s*\$null -ne \$state\s*$' }
        @{ What = 'first test'; Pattern = "Test-Deployment -Name 'web-frontend' \| Should -BeTrue" }
        @{ What = 'default mock'; Pattern = "Mock Get-DeploymentState \{ 'Succeeded' \}\s*$" }
    ) {
        # @(): a one-line result comes back as a string, and [0] of a string is a char.
        $before = @(Get-MatchingLine 'before.ps1' $Pattern)
        $after = @(Get-MatchingLine 'after.ps1' $Pattern)
        $before.Count | Should -Be 1
        $after.Count | Should -Be 1
        $after[0] | Should -BeExactly $before[0]
    }
    It 'before.ps1 has no mock that answers a failure and no canary' {
        Get-Content -LiteralPath (Join-Path $script:Dir 'before.ps1') -Raw | Should -Not -Match "ParameterFilter|canary|'Failed'|-BeFalse"
    }
}

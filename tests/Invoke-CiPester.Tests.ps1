BeforeAll {
    $script:Tool = Join-Path $PSScriptRoot '../tools/Invoke-CiPester.ps1'
    $script:Pwsh = (Get-Process -Id $PID).Path

    # Each fixture is a directory of test files run by the real tool in a child process.
    function script:Invoke-Fixture {
        param([string]$Name, [hashtable]$Files, [string]$Allow, [string]$AllowPath)
        $dir = Join-Path $TestDrive $Name
        $null = New-Item -ItemType Directory -Path $dir
        foreach ($f in $Files.Keys) { Set-Content -LiteralPath (Join-Path $dir $f) -Value $Files[$f] }
        $extra = @()
        if ($PSBoundParameters.ContainsKey('Allow')) {
            $af = Join-Path $TestDrive "$Name-allow.txt"
            Set-Content -LiteralPath $af -Value $Allow
            $extra = @('-AllowSkipPath', $af)
        }
        if ($AllowPath) { $extra = @('-AllowSkipPath', $AllowPath) }
        $out = & $script:Pwsh -NoProfile -File $script:Tool -Path $dir -Output None @extra 2>&1 | Out-String
        [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
    }
    $script:Good = "Describe 'ok' { It 'runs' { 1 | Should -Be 1 } }"
    $script:Skipped = "Describe 'sk' { It 'skipped it' -Skip { 1 | Should -Be 1 } }"
}

Describe 'Invoke-CiPester' {
    It 'accepts a clean directory' {
        $r = Invoke-Fixture 'clean' @{ 'Good.Tests.ps1' = $script:Good }
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'accepted'
    }
    It 'does not impose strict mode or Stop on the tests it runs' {
        $t = "Describe 'lenient' { It 'reads a missing property' { `$o = [pscustomobject]@{}; [bool]`$o.Missing | Should -BeFalse; Write-Error 'non-terminating' -ErrorAction Continue } }"
        $r = Invoke-Fixture 'lenient' @{ 'Lenient.Tests.ps1' = $t }
        $r.Code | Should -Be 0
    }
    It 'rejects a failed test' {
        $r = Invoke-Fixture 'failed' @{ 'Good.Tests.ps1' = $script:Good; 'Fail.Tests.ps1' = "Describe 'x' { It 'fails' { 1 | Should -Be 2 } }" }
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'failed test'
    }
    It 'rejects a file that fails discovery although another file passes' {
        $r = Invoke-Fixture 'discovery' @{ 'Good.Tests.ps1' = $script:Good; 'Bad.Tests.ps1' = "throw 'discovery failure'" }
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'failed container'
    }
    It 'rejects a block-setup failure although another file passes' {
        $r = Invoke-Fixture 'setup' @{ 'Good.Tests.ps1' = $script:Good; 'Setup.Tests.ps1' = "Describe 'x' { BeforeAll { throw 'setup failure' } It 'never runs' { 1 | Should -Be 1 } }" }
        $r.Code | Should -Be 1
    }
    It 'rejects a run with zero tests' {
        $r = Invoke-Fixture 'zero' @{ 'Empty.Tests.ps1' = "Describe 'none' { }" }
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'no tests ran'
    }
    It 'rejects a skipped test that is not on the allowlist and names it' {
        $r = Invoke-Fixture 'skipped' @{ 'Good.Tests.ps1' = $script:Good; 'Skip.Tests.ps1' = $script:Skipped } -Allow ''
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'skipped test\(s\) not on the allowlist'
        $r.Output | Should -Match 'sk\.skipped it'
    }
    It 'rejects a skipped test when the default allowlist does not list it' {
        $r = Invoke-Fixture 'skipped-default' @{ 'Skip.Tests.ps1' = $script:Skipped }
        $r.Code | Should -Be 1
    }
    It 'rejects the child tests of a skipped Describe' {
        $t = "Describe 'sd' -Skip:`$true { It 'a' { 1 | Should -Be 1 }; It 'b' { 1 | Should -Be 1 } }"
        $r = Invoke-Fixture 'skipped-describe' @{ 'Good.Tests.ps1' = $script:Good; 'SkipD.Tests.ps1' = $t } -Allow ''
        $r.Code | Should -Be 1
        $r.Output | Should -Match '2 skipped test'
    }
    It 'accepts a skipped test that is allowlisted with a reason, and reports the counts' {
        $r = Invoke-Fixture 'allowed' @{ 'Good.Tests.ps1' = $script:Good; 'Skip.Tests.ps1' = $script:Skipped } -Allow "# comment`n`nsk.skipped it | needs a tool the runner lacks"
        $r.Code | Should -Be 0
        $r.Output | Should -Match '1 skipped \(1 allowlisted\)'
        $r.Output | Should -Match '1 evaluated'
    }
    It 'reports zero skipped on a clean run' {
        $r = Invoke-Fixture 'clean-count' @{ 'Good.Tests.ps1' = $script:Good } -Allow ''
        $r.Code | Should -Be 0
        $r.Output | Should -Match '0 skipped'
    }
    It 'rejects an allowlist entry without a reason' {
        foreach ($line in 'sk.skipped it', 'sk.skipped it |', 'sk.skipped it |   ') {
            $r = Invoke-Fixture ('noreason' + [guid]::NewGuid().ToString('N')) @{ 'Skip.Tests.ps1' = $script:Skipped } -Allow $line
            $r.Code | Should -Be 1 -Because "'$line' has no reason"
            $r.Output | Should -Match 'allowlist entry without a reason'
        }
    }
    It 'rejects a missing allowlist file that was named explicitly' {
        $r = Invoke-Fixture 'nofile' @{ 'Good.Tests.ps1' = $script:Good } -AllowPath (Join-Path $TestDrive 'absent.txt')
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'allowlist .* not found'
    }
    It 'still lists a stale allowlist entry as a note without failing' {
        $r = Invoke-Fixture 'stale' @{ 'Good.Tests.ps1' = $script:Good } -Allow 'gone.test | no longer skipped'
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'allowlisted but not skipped: gone.test'
    }
}

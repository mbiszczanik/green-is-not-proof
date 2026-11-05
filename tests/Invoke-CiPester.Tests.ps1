BeforeAll {
    $script:Tool = Join-Path $PSScriptRoot '../tools/Invoke-CiPester.ps1'
    $script:Pwsh = (Get-Process -Id $PID).Path

    # Each fixture is a directory of test files run by the real tool in a child process.
    function script:Invoke-Fixture {
        param([string]$Name, [hashtable]$Files)
        $dir = Join-Path $TestDrive $Name
        $null = New-Item -ItemType Directory -Path $dir
        foreach ($f in $Files.Keys) { Set-Content -LiteralPath (Join-Path $dir $f) -Value $Files[$f] }
        $out = & $script:Pwsh -NoProfile -File $script:Tool -Path $dir -Output None 2>&1 | Out-String
        [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
    }
    $script:Good = "Describe 'ok' { It 'runs' { 1 | Should -Be 1 } }"
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
}

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Pwsh = (Get-Process -Id $PID).Path
    . (Join-Path $script:Root 'scripts/Invoke-OfflinePack.ps1')

    # A fake demo has one step; the fake runner decides what the step prints and exits with.
    function script:New-FakeDemo([string]$Id, [string[]]$Requires = @()) {
        @{ Id = $Id; Title = "fake $Id"; Requires = $Requires; Steps = @(
                @{ Label = "step of $Id"; Kind = 'Fake'; ExpectExit = 0; Show = @(
                        @{ Role = 'Green'; Pattern = '^green line$' }
                        @{ Role = 'Reveal'; Pattern = '^reveal line$' }
                    ) }
            ) }
    }
    function script:Invoke-Pack([hashtable[]]$Demo, [scriptblock]$GetVersion, [scriptblock]$Runner) {
        $all = @(Invoke-OfflinePack -Demo $Demo -GetVersion $GetVersion -Runner $Runner 6>&1)
        [pscustomobject]@{
            ExitCode = @($all | Where-Object { $_ -is [pscustomobject] })[-1].ExitCode
            Text     = (@($all | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { "$_" }) -join "`n")
        }
    }
    $script:AllTools = { '1.0' }
    $script:GoodRunner = { [pscustomobject]@{ ExitCode = 0; Line = @('green line', 'reveal line') } }
}

Describe 'Invoke-OfflinePack outcome rules' {
    It 'exits 0 and prints the green line and the reveal line of each demo when every demo passes' {
        $r = Invoke-Pack -Demo @((New-FakeDemo '1'), (New-FakeDemo '2')) -GetVersion $script:AllTools -Runner $script:GoodRunner
        $r.ExitCode | Should -Be 0
        $r.Text | Should -Match 'Green:\s+green line'
        $r.Text | Should -Match 'Reveal:\s+reveal line'
        $r.Text | Should -Match 'Offline pack: 2 passed, 0 failed, 0 not run'
    }

    It 'names the missing prerequisite, skips only that demo, reports it as not run and exits 1' {
        $ran = [System.Collections.Generic.List[string]]::new()
        $runner = { param($Step) $ran.Add($Step.Label); [pscustomobject]@{ ExitCode = 0; Line = @('green line', 'reveal line') } }
        $tools = { param($Name) if ($Name -eq 'Bicep CLI') { '' } else { '1.0' } }
        $r = Invoke-Pack -Demo @((New-FakeDemo '1' -Requires 'Bicep CLI'), (New-FakeDemo '2' -Requires 'Pester')) -GetVersion $tools -Runner $runner
        $r.ExitCode | Should -Be 1
        $r.Text | Should -Match 'NOT RUN: missing Bicep CLI'
        $r.Text | Should -Match 'Demo 1: NOT RUN \(missing Bicep CLI\)'
        $r.Text | Should -Match 'Demo 2: PASSED'
        @($ran) | Should -Be @('step of 2')
    }

    It 'names the demo and exits 1 when a command exits with another code than documented' {
        $runner = { [pscustomobject]@{ ExitCode = 3; Line = @('green line', 'reveal line') } }
        $r = Invoke-Pack -Demo @((New-FakeDemo '7')) -GetVersion $script:AllTools -Runner $runner
        $r.ExitCode | Should -Be 1
        $r.Text | Should -Match 'Demo 7: FAILED \(.*exit code 3, expected 0'
    }

    It 'fails a demo whose output stops showing its reveal even though the exit code is right' {
        $runner = { [pscustomobject]@{ ExitCode = 0; Line = @('green line') } }
        $r = Invoke-Pack -Demo @((New-FakeDemo '4')) -GetVersion $script:AllTools -Runner $runner
        $r.ExitCode | Should -Be 1
        $r.Text | Should -Match 'Demo 4: FAILED \(.*reveal line'
    }

    It 'fails a demo whose runner throws instead of passing it' {
        $runner = { throw 'boom' }
        $r = Invoke-Pack -Demo @((New-FakeDemo '6')) -GetVersion $script:AllTools -Runner $runner
        $r.ExitCode | Should -Be 1
        $r.Text | Should -Match 'Demo 6: FAILED'
    }

    It 'does not report success when no demo was selected' {
        (Invoke-Pack -Demo @() -GetVersion $script:AllTools -Runner $script:GoodRunner).ExitCode | Should -Be 1
    }
}

Describe 'the demo list' {
    It 'covers demos 2, 3, 4, 6 and 7' {
        (Get-OfflineDemo -Root $script:Root | ForEach-Object { $_.Id }) -join ',' | Should -Be '2,3,4,6,7'
    }
    It 'gives demo <id> an exercise and an answer key in separate files' -ForEach @('2', '3', '4', '6', '7' | ForEach-Object { @{ id = $_ } }) {
        $ex = Join-Path $script:Root "docs/student-pack/exercises/demo-$id.md"
        $an = Join-Path $script:Root "docs/student-pack/answers/demo-$id.md"
        Test-Path -LiteralPath $ex | Should -BeTrue -Because "$ex must exist"
        Test-Path -LiteralPath $an | Should -BeTrue -Because "$an must exist"
        (Get-Content -LiteralPath $ex -Raw) | Should -Not -Match '(?im)^#+\s*answer' -Because 'the answer belongs in the answer key'
        (Get-Content -LiteralPath $an -Raw).Trim().Length | Should -BeGreaterThan 100
    }
}

Describe 'Invoke-OfflinePack.ps1 on this machine (child process, real demos)' {
    It 'runs demo 4 alone and exits 0 with the green result and the reveal printed' {
        $out = & $script:Pwsh -NoProfile -File (Join-Path $script:Root 'scripts/Invoke-OfflinePack.ps1') -Demo 4 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
        $text = $out -join "`n"
        $code | Should -Be 0 -Because $text
        $text | Should -Match 'Green:\s+Process exit code: 0'
        $text | Should -Match 'Reveal:\s+The gate would PASS although the output shows a failure\.'
        $text | Should -Match 'Offline pack: 1 passed, 0 failed, 0 not run'
    }
    It 'exits 1 and names an unknown demo id instead of running nothing' {
        $out = & $script:Pwsh -NoProfile -File (Join-Path $script:Root 'scripts/Invoke-OfflinePack.ps1') -Demo 5 2>&1 | ForEach-Object { "$_" }
        $LASTEXITCODE | Should -Be 1
        ($out -join "`n") | Should -Match 'Unknown demo: 5'
    }
    It 'runs every offline demo and exits 0' {
        $out = & $script:Pwsh -NoProfile -File (Join-Path $script:Root 'scripts/Invoke-OfflinePack.ps1') 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
        $text = $out -join "`n"
        $code | Should -Be 0 -Because $text
        $text | Should -Match 'Offline pack: 5 passed, 0 failed, 0 not run'
    }
}

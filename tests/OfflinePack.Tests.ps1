BeforeDiscovery {
    $script:HasAll = [bool](Get-Module -ListAvailable PSRule.Rules.Azure) -and [bool](Get-Module -ListAvailable PSRule) -and
        ([bool](Get-Command bicep -ErrorAction SilentlyContinue) -or [bool](Get-Command az -ErrorAction SilentlyContinue))
}

BeforeAll {
    $script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $script:Pack = Join-Path $script:Root 'scripts/Invoke-OfflinePack.ps1'
    $script:Pwsh = (Get-Process -Id $PID).Path
    . $script:Pack

    # Every line a step must print, so one stub output satisfies each step.
    $script:AllLines = @(
        'Tests Passed: 1, Failed: 1', '[-] Deploy-Example.ps1 has no unguarded mutation', 'Tests Passed: 1, Failed: 0',
        'The gate would PASS although the output shows a failure.', 'Process exit code: 1',
        'The gate would PASS although the output shows a diagnostic.', 'Fixed gate: FAIL',
        'The gate would PASS although no rule was evaluated.'
    )

    function script:Invoke-Pack {
        $all = @(Invoke-OfflinePack -Root $script:Root 6>&1)
        [pscustomobject]@{
            Code = @($all | Where-Object { $_ -is [int] })[-1]
            Text = (@($all | Where-Object { $_ -isnot [int] } | ForEach-Object { "$_" }) -join "`n")
        }
    }
}

Describe 'Invoke-OfflinePack with stubbed steps' {
    BeforeEach {
        $script:Missing = @()
        $script:BadTarget = ''
        $script:BadResult = $null
        Mock Test-PackPrerequisite { $Name -notin $script:Missing }
        Mock Invoke-PackStep {
            if ($script:BadTarget -and $Step.Target -match $script:BadTarget) {
                if ($null -eq $script:BadResult) { throw 'the child process could not start' }
                return $script:BadResult
            }
            [pscustomobject]@{ Code = $Step.ExpectExit; Line = $script:AllLines }
        }
    }

    It 'returns 0 and reports every offline demo when each step matches' {
        $r = Invoke-Pack
        $r.Code | Should -Be 0
        foreach ($id in '2', '3', '4', '6', '7') { $r.Text | Should -Match "OK: demo $id showed its green and its reveal\." }
        $r.Text | Should -Match 'Offline pack: 5 ok, 0 not run, 0 failed'
        Should -Invoke Invoke-PackStep -Times 8 -Exactly
    }

    It 'prints a Green and a Reveal line for every demo' {
        $r = Invoke-Pack
        @([regex]::Matches($r.Text, '(?m)^-- Green: ')).Count | Should -Be 5
        @([regex]::Matches($r.Text, '(?m)^-- Reveal: ')).Count | Should -Be 5
    }

    It 'names a missing <Need>, skips only demo(s) <Skipped> and returns 1' -ForEach @(
        @{ Need = 'Bicep CLI'; Skipped = @('6'); Ran = @('2', '3', '4', '7'); Steps = 6 }
        @{ Need = 'PSRule'; Skipped = @('7'); Ran = @('2', '3', '4', '6'); Steps = 6 }
        @{ Need = 'Pester'; Skipped = @('2', '3', '4'); Ran = @('6', '7'); Steps = 4 }
    ) {
        $script:Missing = @($Need)
        $r = Invoke-Pack
        $r.Code | Should -Be 1
        foreach ($id in $Skipped) {
            $r.Text | Should -Match "NOT RUN: demo $id needs $Need, which is missing\."
            $r.Text | Should -Match "Not run: demo $id \(missing: $Need\)"
        }
        foreach ($id in $Ran) { $r.Text | Should -Match "OK: demo $id " }
        $r.Text | Should -Match "Offline pack: $($Ran.Count) ok, $($Skipped.Count) not run, 0 failed"
        Should -Invoke Invoke-PackStep -Times $Steps -Exactly
    }

    It 'runs nothing and returns 1 without PowerShell 7' {
        $script:Missing = @('PowerShell 7')
        $r = Invoke-Pack
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'Missing prerequisite: PowerShell 7\. No demo was run\.'
        $r.Text | Should -Match 'Offline pack: 0 ok, 5 not run, 0 failed'
        Should -Invoke Invoke-PackStep -Times 0 -Exactly
    }

    It 'returns 1 and names the demo when a step ends with another exit code' {
        $script:BadTarget = '4-gate-never-red'
        $script:BadResult = [pscustomobject]@{ Code = 3; Line = $script:AllLines }
        $r = Invoke-Pack
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'FAILED: demo 4: step Green ended with exit code 3, expected 0'
        foreach ($id in '2', '3', '6', '7') { $r.Text | Should -Match "OK: demo $id " }
        $r.Text | Should -Match 'Offline pack: 4 ok, 0 not run, 1 failed'
    }

    It 'returns 1 and names the demo when a step does not print the expected line' {
        $script:BadTarget = '6-lint-warns-gate-passes'
        $script:BadResult = [pscustomobject]@{ Code = 0; Line = @('Bare gate: PASS') }
        $r = Invoke-Pack
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'FAILED: demo 6: step Green did not print the expected line'
    }

    It 'returns 1 and names the demo when a step cannot start' {
        $script:BadTarget = '7-unprocessed-object-passes'
        $r = Invoke-Pack
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'FAILED: demo 7: step Green could not start: the child process could not start'
    }

    It 'prints no local path of the repository' {
        $script:BadTarget = '4-gate-never-red'
        $script:BadResult = [pscustomobject]@{ Code = 0; Line = @("at $script:Root/demos/x.ps1") + $script:AllLines }
        (Invoke-Pack).Text | Should -Not -Match ([regex]::Escape($script:Root))
    }
}

Describe 'offline demo definitions' {
    It 'cover demos 2, 3, 4, 6 and 7' {
        (@(Get-OfflineDemo -Root $script:Root) | ForEach-Object { $_.Id }) -join ',' | Should -Be '2,3,4,6,7'
    }

    It 'point every step that runs at a path that exists' {
        $targets = @(Get-OfflineDemo -Root $script:Root | ForEach-Object { $_.Steps } | Where-Object { $_.Kind -ne 'Text' } | ForEach-Object { $_.Target })
        $targets.Count | Should -Be 8
        foreach ($t in $targets) { $t | Should -Exist }
    }
}

Describe 'student pack documents' {
    It '<File> has a section for every offline demo' -ForEach @(@{ File = 'exercises.md' }, @{ File = 'answers.md' }) {
        $lines = @(Get-Content -LiteralPath (Join-Path $script:Root "docs/student-pack/$File"))
        foreach ($id in '2', '3', '4', '6', '7') { @($lines | Where-Object { $_ -match "^## Demo $id\b" }).Count | Should -Be 1 }
    }

    It 'keeps the answer key out of the exercises' {
        Get-Content -LiteralPath (Join-Path $script:Root 'docs/student-pack/exercises.md') -Raw | Should -Not -Match '(?m)^#+ .*Answer'
    }
}

Describe 'Invoke-OfflinePack.ps1 as a process, with the real demos' -Skip:(-not $script:HasAll) {
    It 'exits 0 and reports all five demos' {
        $out = (& $script:Pwsh -NoProfile -File $script:Pack 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $LASTEXITCODE | Should -Be 0 -Because $out
        foreach ($id in '2', '3', '4', '6', '7') { $out | Should -Match "OK: demo $id showed its green and its reveal\." }
        $out | Should -Match 'Offline pack: 5 ok, 0 not run, 0 failed'
    }
}

BeforeAll {
    $script:Dir = Join-Path $PSScriptRoot '../demos/4-gate-never-red'
    $script:Pwsh = (Get-Process -Id $PID).Path
    function script:Invoke-Validator {
        param([string]$Name, [string]$State)
        $out = & $script:Pwsh -NoProfile -File (Join-Path $script:Dir "Test-Lab.$Name.ps1") -StatePath $State 2>&1 | ForEach-Object { "$_" }
        [pscustomobject]@{ Code = $LASTEXITCODE; Output = @($out); FailLines = @($out | Where-Object { $_ -match '^\[FAIL\]' }).Count }
    }
    $script:Empty = Join-Path $script:Dir 'state-empty.json'
    $script:Ok = Join-Path $script:Dir 'state-ok.json'
    $script:Partial = Join-Path $TestDrive 'state-partial.json'
    '{"resourceGroups":["lab-rg"],"locks":[]}' | Set-Content $script:Partial
    $script:Garbage = Join-Path $TestDrive 'state-garbage.json'
    '{ not json' | Set-Content $script:Garbage
    $script:States = @{ Empty = $script:Empty; Ok = $script:Ok; Partial = $script:Partial; Garbage = $script:Garbage }
}

Describe 'Demo 4 inputs document the two ways a gate stays green' {
    It 'Silent prints [FAIL] and exits 0 on an empty state' {
        $r = Invoke-Validator Silent $script:Empty
        $r.FailLines | Should -Be 2
        $r.Code | Should -Be 0
    }

    It 'Counted counts the failures and calls exit 1, but the process exits 0 under #Requires' {
        $r = Invoke-Validator Counted $script:Empty
        $r.FailLines | Should -Be 2
        $r.Output[-1] | Should -Be 'Validation complete: 2 failed.'
        $r.Code | Should -Be 0 -Because 'PowerShell drops the exit code of a script with #Requires -Modules under pwsh -File (SkyCraft PR 109); if this starts failing, the platform fixed it and the demo needs a new story'
    }
}

Describe 'Demo 4 fixed validator' {
    It 'exits 1 on an empty state' {
        (Invoke-Validator Fixed $script:Empty).Code | Should -Be 1
    }

    It 'exits 0 on a complete state' {
        $r = Invoke-Validator Fixed $script:Ok
        $r.Code | Should -Be 0
        $r.FailLines | Should -Be 0
    }

    It 'exits 1 when only part of the state is there' {
        (Invoke-Validator Fixed $script:Partial).Code | Should -Be 1
    }

    It 'exits 1 when the state file is missing' {
        $r = Invoke-Validator Fixed (Join-Path $TestDrive 'does-not-exist.json')
        $r.Code | Should -Be 1
        $r.FailLines | Should -BeGreaterThan 0
    }

    It 'exits 1 when the state file cannot be parsed' {
        (Invoke-Validator Fixed $script:Garbage).Code | Should -Be 1
    }

    It 'never exits 0 while its output shows a failure, for every state' -ForEach @(
        @{ Name = 'empty'; Path = 'Empty' }, @{ Name = 'ok'; Path = 'Ok' }, @{ Name = 'partial'; Path = 'Partial' }, @{ Name = 'garbage'; Path = 'Garbage' }
    ) {
        $r = Invoke-Validator Fixed $script:States[$Path]
        ($r.Code -eq 0) | Should -Be ($r.FailLines -eq 0) -Because "state '$Name': exit code $($r.Code), $($r.FailLines) failure line(s)"
    }
}

Describe 'Invoke-Gate' {
    BeforeAll { . (Join-Path $script:Dir 'Invoke-Gate.ps1') -Script Fixed }

    It 'says the gate would pass when the exit code is 0 although the output shows a failure' {
        $text = (Invoke-Gate -ScriptPath (Join-Path $script:Dir 'Test-Lab.Silent.ps1') -StatePath $script:Empty 6>&1 | Out-String)
        $text | Should -Match 'Process exit code: 0'
        $text | Should -Match 'The gate would PASS although the output shows a failure\.'
    }

    It 'returns the exit code of the validator process' {
        $null = Invoke-Gate -ScriptPath (Join-Path $script:Dir 'Test-Lab.Fixed.ps1') -StatePath $script:Empty 6>&1
        (Invoke-Gate -ScriptPath (Join-Path $script:Dir 'Test-Lab.Fixed.ps1') -StatePath $script:Empty 6>$null) | Should -Be 1
    }
}

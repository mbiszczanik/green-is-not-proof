BeforeDiscovery {
    $script:HasLinter = [bool](Get-Command bicep -ErrorAction SilentlyContinue) -or [bool](Get-Command az -ErrorAction SilentlyContinue)
}

BeforeAll {
    $script:Dir = Join-Path $PSScriptRoot '../demos/6-lint-warns-gate-passes'
    $script:Runner = Join-Path $script:Dir 'Invoke-Gate.ps1'
    . $script:Runner -Gate Bare
    $script:Pwsh = (Get-Process -Id $PID).Path
    function script:Invoke-GateProcess {
        param([string]$Gate, [string]$Template)
        $out = @(& $script:Pwsh -NoProfile -File $script:Runner -Gate $Gate -Template $Template 2>&1 | ForEach-Object { "$_" })
        [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
    }
    $script:Warn = 'x.bicep(2,7) : Warning no-unused-params: Parameter "a" is declared but never used. [https://aka.ms/bicep/linter-diagnostics#no-unused-params]'
    $script:Clean = @('')
}

Describe 'Get-LintFinding' {
    It 'finds the plain linter format' {
        @(Get-LintFinding -Line @($script:Warn)).Count | Should -Be 1
    }

    It 'finds the az format with its WARNING prefix' {
        @(Get-LintFinding -Line @("WARNING: $script:Warn")).Count | Should -Be 1
    }

    It 'finds an Error diagnostic' {
        @(Get-LintFinding -Line @('x.bicep(1,1) : Error BCP018: Expected the "=" character.')).Count | Should -Be 1
    }

    It 'ignores prose that only mentions warnings, and empty output' {
        @(Get-LintFinding -Line @('0 warnings, see the warning docs')).Count | Should -Be 0
        @(Get-LintFinding -Line @()).Count | Should -Be 0
    }
}

Describe 'Test-LintGate' {
    It 'Bare passes on exit 0 even with a Warning in the output' {
        Test-LintGate -Gate Bare -ExitCode 0 -Line @($script:Warn) | Should -BeTrue
    }

    It 'Fixed fails on exit 0 with a Warning in the output' {
        Test-LintGate -Gate Fixed -ExitCode 0 -Line @($script:Warn) | Should -BeFalse -Because 'a fixed gate that passes while the output shows a diagnostic would make the demo show a pass it did not earn'
    }

    It 'Fixed fails on exit 0 with an az-prefixed Warning' {
        Test-LintGate -Gate Fixed -ExitCode 0 -Line @("WARNING: $script:Warn") | Should -BeFalse
    }

    It 'both gates pass on exit 0 with a clean output' {
        Test-LintGate -Gate Bare -ExitCode 0 -Line $script:Clean | Should -BeTrue
        Test-LintGate -Gate Fixed -ExitCode 0 -Line $script:Clean | Should -BeTrue
    }

    It 'both gates fail on a non-zero exit code' {
        Test-LintGate -Gate Bare -ExitCode 1 -Line $script:Clean | Should -BeFalse
        Test-LintGate -Gate Fixed -ExitCode 1 -Line $script:Clean | Should -BeFalse
    }
}

Describe 'Hide-LocalPath' {
    It 'replaces the demo folder in both slash styles' {
        $folder = Join-Path $TestDrive 'demo'
        $bs = "$folder\Sample.bicep(2,7) : Warning x"
        $fs = ($folder.Replace('\', '/')) + '/Sample.bicep(2,7) : Warning x'
        Hide-LocalPath -Text $bs -Folder $folder | Should -Be '.\Sample.bicep(2,7) : Warning x'
        Hide-LocalPath -Text $fs -Folder $folder | Should -Be './Sample.bicep(2,7) : Warning x'
    }

    It 'leaves other text unchanged' {
        Hide-LocalPath -Text 'no path here' -Folder $TestDrive | Should -Be 'no path here'
    }
}

Describe 'Invoke-BicepLint without a linter' {
    It 'throws instead of returning a result no gate could trust' {
        Mock Get-Command { $null } -ParameterFilter { $Name -in 'bicep', 'az' }
        { Invoke-BicepLint -Path (Join-Path $script:Dir 'Sample.bicep') } | Should -Throw '*Neither bicep nor az*'
    }
}

Describe 'Demo 6 with the real linter' -Skip:(-not $script:HasLinter) {
    It 'Bare passes on the sample template and says the gate would pass although a diagnostic shows' {
        $r = Invoke-GateProcess Bare 'Sample'
        $r.Code | Should -Be 0 -Because 'the linter exits 0 on a Warning; if this starts failing, the platform changed and the demo needs a new story'
        $r.Output | Should -Contain 'The gate would PASS although the output shows a diagnostic.'
        $r.Output | Should -Contain 'Warning or Error lines in the output: 1'
    }

    It 'Fixed fails on the sample template' {
        (Invoke-GateProcess Fixed 'Sample').Code | Should -Be 1
    }

    It 'both gates pass on the clean template without the warning line' {
        foreach ($g in 'Bare', 'Fixed') {
            $r = Invoke-GateProcess $g 'Clean'
            $r.Code | Should -Be 0
            $r.Output | Should -Not -Contain 'The gate would PASS although the output shows a diagnostic.'
        }
    }

    It 'prints no local path' {
        $text = (Invoke-GateProcess Bare 'Sample').Output -join "`n"
        $text | Should -Not -Match ([regex]::Escape((Resolve-Path $script:Dir).Path))
        $text | Should -Not -Match ([regex]::Escape($HOME))
    }
}

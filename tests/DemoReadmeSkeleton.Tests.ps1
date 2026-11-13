BeforeDiscovery {
    $script:Demos = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../demos') -Directory | Sort-Object Name |
            ForEach-Object { @{ Demo = $_.Name; Path = (Join-Path $_.FullName 'README.md') } })
}

BeforeAll {
    $script:Steps = @(
        @{ Name = 'Predict'; Heading = '### 1. Predict' }
        @{ Name = 'Run'; Heading = '### 2. Run' }
        @{ Name = 'Reveal'; Heading = '### 3. Reveal' }
        @{ Name = 'Fix'; Heading = '### 4. Fix' }
        @{ Name = 'Rule'; Heading = '### 5. Rule' }
    )

    function script:Get-SkeletonProblem {
        param([string]$Name, [string[]]$Line)
        $problems = @()
        $at = @{}
        for ($i = 0; $i -lt $Line.Count; $i++) {
            $text = $Line[$i].TrimEnd()
            foreach ($s in $script:Steps) {
                if ($text -ceq $s.Heading -and -not $at.ContainsKey($s.Name)) { $at[$s.Name] = $i }
            }
        }
        $last = -1
        foreach ($s in $script:Steps) {
            if (-not $at.ContainsKey($s.Name)) {
                $problems += "${Name}: step '$($s.Name)' is missing (no heading '$($s.Heading)')"
                continue
            }
            $i = $at[$s.Name]
            if ($i -lt $last) { $problems += "${Name}: step '$($s.Name)' is out of order" }
            $last = $i
            $body = @()
            for ($j = $i + 1; $j -lt $Line.Count -and $Line[$j] -notmatch '^#{1,6}\s'; $j++) {
                if ($Line[$j].Trim()) { $body += $Line[$j].Trim() }
            }
            if ($body.Count -eq 0) { $problems += "${Name}: step '$($s.Name)' is empty"; continue }
            $joined = $body -join ' '
            if ($s.Name -eq 'Predict' -and $joined -notmatch '\?') {
                $problems += "${Name}: step 'Predict' asks no question"
            }
            # One sentence: a single sentence end, and it is the last character.
            if ($s.Name -eq 'Rule' -and ([regex]::Matches($joined, '[.!?](?=\s|$)').Count -ne 1 -or -not $joined.EndsWith('.'))) {
                $problems += "${Name}: step 'Rule' is not one sentence"
            }
        }
        if ($at.ContainsKey('Predict')) {
            for ($k = 0; $k -lt $at['Predict']; $k++) {
                if ($Line[$k] -match '^\s*```') {
                    $problems += "${Name}: a command block comes before step 'Predict'"
                    break
                }
            }
        }
        $problems
    }
}

Describe 'demo READMEs follow the five teaching steps' {
    It 'finds the eight demo folders' {
        @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../demos') -Directory).Count | Should -BeGreaterOrEqual 8
    }

    It '<Demo> has Predict, Run, Reveal, Fix and Rule, in that order' -ForEach $script:Demos {
        $Path | Should -Exist
        $lines = @(Get-Content -LiteralPath $Path)
        (@(Get-SkeletonProblem -Name "demos/$Demo/README.md" -Line $lines) -join '; ') | Should -BeNullOrEmpty
    }
}

Describe 'the skeleton check on a made-up README' {
    BeforeAll {
        $script:Good = @(
            '# Demo X', '', 'Intro.', '', '## Five steps', '',
            '### 1. Predict', '', 'Does it fail?', '',
            '### 2. Run', '', '`./run.ps1` exits 0.', '',
            '### 3. Reveal', '', 'It printed a failure.', '',
            '### 4. Fix', '', 'The fixed variant exits 1.', '',
            '### 5. Rule', '', 'A green is a declaration; read it back.', '',
            '## On stage', '', '```powershell', './run.ps1', '```'
        )
        function script:Get-Problem {
            param([string[]]$Line)
            @(Get-SkeletonProblem -Name 'demos/x/README.md' -Line $Line) -join '; '
        }
    }

    It 'accepts a README with the five steps' {
        Get-Problem -Line $script:Good | Should -BeNullOrEmpty
    }

    It 'names the README and the step when <Step> is missing' -ForEach @(
        @{ Step = 'Predict' }, @{ Step = 'Run' }, @{ Step = 'Reveal' }, @{ Step = 'Fix' }, @{ Step = 'Rule' }
    ) {
        $lines = @($script:Good | Where-Object { $_ -notmatch "^### \d\. $Step$" })
        Get-Problem -Line $lines | Should -Match "demos/x/README\.md: step '$Step' is missing"
    }

    It 'rejects a README without any step' {
        $p = Get-Problem -Line @('# Demo X', '', 'Intro.')
        foreach ($s in 'Predict', 'Run', 'Reveal', 'Fix', 'Rule') { $p | Should -Match "step '$s' is missing" }
    }

    It 'rejects an empty step' {
        $lines = @($script:Good | Where-Object { $_ -ne 'The fixed variant exits 1.' })
        Get-Problem -Line $lines | Should -Match "step 'Fix' is empty"
    }

    It 'rejects steps out of order' {
        $lines = @($script:Good | ForEach-Object {
                if ($_ -eq '### 3. Reveal') { '### 4. Fix' } elseif ($_ -eq '### 4. Fix') { '### 3. Reveal' } else { $_ }
            })
        Get-Problem -Line $lines | Should -Match "step 'Fix' is out of order"
    }

    It 'rejects a prediction that asks no question' {
        $lines = @($script:Good | ForEach-Object { if ($_ -eq 'Does it fail?') { 'It fails.' } else { $_ } })
        Get-Problem -Line $lines | Should -Match "step 'Predict' asks no question"
    }

    It 'rejects a rule of two sentences' {
        $lines = @($script:Good | ForEach-Object {
                if ($_ -eq 'A green is a declaration; read it back.') { 'A green is a declaration. Read it back.' } else { $_ }
            })
        Get-Problem -Line $lines | Should -Match "step 'Rule' is not one sentence"
    }

    It 'rejects a command block before the prediction' {
        $lines = @('# Demo X', '', '```powershell', './run.ps1', '```', '') + @($script:Good | Select-Object -Skip 2)
        Get-Problem -Line $lines | Should -Match "a command block comes before step 'Predict'"
    }
}

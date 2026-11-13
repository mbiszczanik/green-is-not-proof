BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

    # Returns one problem string per defect; empty means the README follows the skeleton.
    function script:Get-SkeletonProblem([string]$Text) {
        $steps = 'Predict', 'Run', 'Reveal', 'Fix', 'Rule'
        $lines = $Text -split "`r?`n"
        $problems = @()
        $at = @{}
        $body = @{}
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^### (Predict|Run|Reveal|Fix|Rule)\s*$' -and -not $at.ContainsKey($Matches[1])) {
                $name = $Matches[1]
                $at[$name] = $i
                $end = $lines.Count
                for ($j = $i + 1; $j -lt $lines.Count; $j++) { if ($lines[$j] -match '^#{1,6} ') { $end = $j; break } }
                $body[$name] = if ($end -gt $i + 1) { ($lines[($i + 1)..($end - 1)] -join "`n").Trim() } else { '' }
            }
        }
        foreach ($s in $steps) {
            if (-not $at.ContainsKey($s)) { $problems += "missing step '$s'" }
            elseif (-not $body[$s]) { $problems += "step '$s' is empty" }
        }
        $present = @($steps | Where-Object { $at.ContainsKey($_) })
        for ($k = 1; $k -lt $present.Count; $k++) {
            if ($at[$present[$k]] -lt $at[$present[$k - 1]]) { $problems += "step '$($present[$k])' comes before '$($present[$k - 1])'" }
        }
        $fence = @(0..($lines.Count - 1) | Where-Object { $lines[$_] -match '^\s*```' })
        if ($at.ContainsKey('Predict')) {
            if ($fence.Count -gt 0 -and $at['Predict'] -gt $fence[0]) { $problems += "step 'Predict' comes after the first command" }
            if ($body['Predict'] -and $body['Predict'] -notmatch '\?') { $problems += "step 'Predict' asks no question" }
        }
        if ($body['Run'] -and $body['Run'] -notmatch '(?m)^\s*```') { $problems += "step 'Run' shows no command" }
        if ($body['Fix']) {
            if ($body['Fix'] -match '^No fixed variant\.') {
                if ($body['Fix'] -notmatch 'The check that settles the question: `[^`]+`') {
                    $problems += "step 'Fix' says there is no fixed variant but names no settling check"
                }
            } elseif ($body['Fix'] -notmatch '`[^`]+`') { $problems += "step 'Fix' names no file, flag or command" }
        }
        if ($body['Rule']) {
            if ($body['Rule'] -match '\n\s*\n' -or $body['Rule'] -cmatch '[.!?]\s+[A-Z]' -or $body['Rule'] -notmatch '\.$') {
                $problems += "step 'Rule' is not one sentence"
            }
        }
        $problems
    }

    $script:Good = @'
# Demo X

### Predict

Will it pass?

### Run

```powershell
./x.ps1
```

### Reveal

It passed because nothing ran.

### Fix

The fixed variant, `x.Fixed.ps1`, fails on nothing run.

### Rule

A pass is a declaration, so read what ran.
'@
}

Describe 'the skeleton check itself fails on bad input' {
    It 'accepts a complete README' {
        @(Get-SkeletonProblem $script:Good) | Should -BeNullOrEmpty
    }
    It 'names the missing step <step>' -ForEach @('Predict', 'Run', 'Reveal', 'Fix', 'Rule' | ForEach-Object { @{ step = $_ } }) {
        $text = $script:Good -replace "(?m)^### $step\s*$", "#### $step"
        (Get-SkeletonProblem $text) -join '|' | Should -Match "missing step '$step'"
    }
    It 'rejects an empty step' {
        (Get-SkeletonProblem ($script:Good -replace 'It passed because nothing ran\.', '')) -join '|' | Should -Match "step 'Reveal' is empty"
    }
    It 'rejects steps out of order' {
        $text = $script:Good -replace '### Predict', '### Reveal2' -replace '### Rule', '### Predict' -replace '### Reveal2', '### Rule'
        (Get-SkeletonProblem $text) -join '|' | Should -Match 'comes before'
    }
    It 'rejects a prediction placed after the first command' {
        $text = "# Demo X`n`n``````powershell`n./early.ps1`n```````n`n" + ($script:Good -replace '^# Demo X\s*', '')
        (Get-SkeletonProblem $text) -join '|' | Should -Match "'Predict' comes after the first command"
    }
    It 'rejects a prediction that asks no question' {
        (Get-SkeletonProblem ($script:Good -replace 'Will it pass\?', 'It will pass.')) -join '|' | Should -Match 'asks no question'
    }
    It 'rejects a Run step without a command' {
        $text = $script:Good -replace '(?s)### Run.*?### Reveal', "### Run`n`nit ran.`n`n### Reveal"
        (Get-SkeletonProblem $text) -join '|' | Should -Match "'Run' shows no command"
    }
    It 'rejects "no fixed variant" without a settling check' {
        $text = $script:Good -replace 'The fixed variant, `x.Fixed.ps1`, fails on nothing run\.', 'No fixed variant.'
        (Get-SkeletonProblem $text) -join '|' | Should -Match 'names no settling check'
    }
    It 'accepts "no fixed variant" with a settling check' {
        $text = $script:Good -replace 'The fixed variant, `x.Fixed.ps1`, fails on nothing run\.', 'No fixed variant. The check that settles the question: `y.ps1`.'
        @(Get-SkeletonProblem $text) | Should -BeNullOrEmpty
    }
    It 'rejects a rule of two sentences' {
        (Get-SkeletonProblem ($script:Good -replace 'so read what ran\.', 'so read what ran. Always.')) -join '|' | Should -Match 'not one sentence'
    }
}

Describe 'every demo README follows predict, run, reveal, fix, rule' {
    It 'finds the demo READMEs' {
        @(Get-ChildItem -Path (Join-Path $script:Root 'demos') -Filter README.md -Recurse).Count | Should -BeGreaterOrEqual 8
    }
    It '<name>' -ForEach @(
        Get-ChildItem -Path (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'demos') -Filter README.md -Recurse |
            Sort-Object FullName | ForEach-Object { @{ name = "demos/$($_.Directory.Name)/README.md"; path = $_.FullName } }
    ) {
        $p = @(Get-SkeletonProblem (Get-Content -LiteralPath $path -Raw))
        $p | Should -BeNullOrEmpty -Because "$name has: $($p -join '; ')"
    }
}

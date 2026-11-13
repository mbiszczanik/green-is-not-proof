BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Heading = '## Canary per pattern'
    $script:NoCanary = 'no canary yet'
    $script:OfflineDemos = '2', '4', '6', '7'
    $script:CanaryForm = '^`(?<File>[^`]+)`, It `(?<Title>[^`]+)`$'

    function script:Get-ItTitle {
        param([string]$Path)
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
        $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'It' }, $true) |
            ForEach-Object { $_.CommandElements[1] } |
            Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] } |
            ForEach-Object { $_.Value }
    }

    function script:Get-CanaryRowProblem {
        param([string[]]$Cell, [string]$Root)
        $row = "row for demo '$($Cell[0])'"
        if ($Cell.Count -ne 4) { return "${row}: $($Cell.Count) cell(s), expected 4" }
        if (-not $Cell[1] -or -not $Cell[2]) { return "${row}: the pattern or the question is empty" }
        if ($Cell[3] -ceq $script:NoCanary) { return }
        $m = [regex]::Match($Cell[3], $script:CanaryForm)
        if (-not $m.Success) {
            return "${row}: canary '$($Cell[3])' is neither a test file with an It title nor '$script:NoCanary'"
        }
        $file = $m.Groups['File'].Value
        $title = $m.Groups['Title'].Value
        # No '..' can pass: one folder level under tests/ or under the row's own demo folder.
        if ($file -notmatch "^(tests|demos/$([regex]::Escape($Cell[0]))-[^/]+)/[^/]+\.Tests\.ps1$") {
            return "${row}: '$file' is not a test file under tests/ or the demo folder"
        }
        $path = Join-Path $Root $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return "${row}: test file '$file' does not exist" }
        if ($title -cnotin @(Get-ItTitle -Path $path)) { return "${row}: '$file' has no It block titled '$title'" }
    }

    function script:Get-CanaryTableProblem {
        param([string[]]$Line, [string]$Root)
        $rows = @()
        $found = $false
        $inSection = $false
        foreach ($l in $Line) {
            if ($l -match '^##\s') {
                $inSection = $l.TrimEnd() -ceq $script:Heading
                if ($inSection) { $found = $true }
                continue
            }
            if (-not $inSection -or $l -notmatch '^\|') { continue }
            $cell = @($l.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
            if ($cell[0] -ceq 'Demo' -or $cell[0] -match '^:?-+:?$') { continue }
            $rows += , $cell
        }
        if (-not $found) { return "section '$script:Heading' is missing" }
        $problems = @()
        if ($rows.Count -lt $script:OfflineDemos.Count) {
            $problems += "the table has $($rows.Count) row(s), expected at least $($script:OfflineDemos.Count)"
        }
        $demos = @($rows | ForEach-Object { $_[0] })
        foreach ($d in $script:OfflineDemos) {
            if ($d -notin $demos) { $problems += "no row for demo $d" }
        }
        foreach ($cell in $rows) { $problems += @(Get-CanaryRowProblem -Cell $cell -Root $Root) }
        $problems
    }
}

Describe 'cheat sheet canary table' {
    It 'names, for each offline demo, a test file and an It title that exist' {
        $lines = Get-Content -LiteralPath (Join-Path $script:Root 'docs/cheat-sheet.md')
        (@(Get-CanaryTableProblem -Line $lines -Root $script:Root) -join '; ') | Should -BeNullOrEmpty
    }
}

Describe 'canary table check on a made-up sheet' {
    BeforeAll {
        $script:Fake = Join-Path $TestDrive 'repo'
        $null = New-Item -ItemType Directory -Path (Join-Path $script:Fake 'tests')
        @("Describe 'fake' {", "    It 'goes red on the unfixed variant' { }", '}') |
            Set-Content -LiteralPath (Join-Path $script:Fake 'tests/Fake.Tests.ps1')

        function script:Get-SheetLine {
            param([string[]]$Row, [string]$Heading = $script:Heading)
            @('# Sheet', '', $Heading, '', '| Demo | Pattern | What would make this red? | Canary |', '| --- | --- | --- | --- |') +
                $Row + @('', '## Source', '', '| 9 | outside | the section | ignored |')
        }
        function script:Get-Row {
            param([string]$Demo, [string]$Canary = '`tests/Fake.Tests.ps1`, It `goes red on the unfixed variant`')
            "| $Demo | a pattern | a question? | $Canary |"
        }
        function script:Get-Problem {
            param([string[]]$Row, [string]$Heading = $script:Heading)
            @(Get-CanaryTableProblem -Line (Get-SheetLine -Row $Row -Heading $Heading) -Root $script:Fake) -join '; '
        }
        $script:Three = @((Get-Row 2), (Get-Row 4), (Get-Row 6))
    }

    It 'accepts four rows that name an existing file and It title' {
        Get-Problem -Row ($script:Three + (Get-Row 7)) | Should -BeNullOrEmpty
    }

    It 'accepts the exact text for a demo without a canary' {
        Get-Problem -Row ($script:Three + (Get-Row 7 $script:NoCanary)) | Should -BeNullOrEmpty
    }

    It 'rejects another wording for a demo without a canary and names the row' {
        Get-Problem -Row ($script:Three + (Get-Row 7 'No canary yet.')) | Should -Match "row for demo '7': canary 'No canary yet\.'"
    }

    It 'rejects a sheet without the section' {
        Get-Problem -Row ($script:Three + (Get-Row 7)) -Heading '## Canaries' | Should -Match 'is missing'
    }

    It 'rejects a table with three rows and names the missing demo' {
        $p = Get-Problem -Row $script:Three
        $p | Should -Match 'the table has 3 row\(s\), expected at least 4'
        $p | Should -Match 'no row for demo 7'
    }

    It 'rejects a test file that does not exist and names the row' {
        $row = Get-Row 4 '`tests/Missing.Tests.ps1`, It `goes red on the unfixed variant`'
        Get-Problem -Row ($script:Three + (Get-Row 7) + $row) | Should -Match "row for demo '4': test file 'tests/Missing\.Tests\.ps1' does not exist"
    }

    It 'rejects an It title that the file does not hold and names the row' {
        $row = Get-Row 6 '`tests/Fake.Tests.ps1`, It `goes red on the unfixed`'
        Get-Problem -Row ($script:Three + (Get-Row 7) + $row) | Should -Match "row for demo '6': 'tests/Fake\.Tests\.ps1' has no It block titled 'goes red on the unfixed'"
    }

    It 'rejects a file outside tests/ and the demo folder' {
        $row = Get-Row 7 '`lib/Fake.Tests.ps1`, It `goes red on the unfixed variant`'
        Get-Problem -Row ($script:Three + $row) | Should -Match "row for demo '7': 'lib/Fake\.Tests\.ps1' is not a test file under tests/ or the demo folder"
    }

    It 'rejects a row with a missing cell' {
        Get-Problem -Row ($script:Three + '| 7 | a pattern | `tests/Fake.Tests.ps1`, It `goes red on the unfixed variant` |') |
            Should -Match "row for demo '7': 3 cell\(s\), expected 4"
    }
}

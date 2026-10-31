BeforeAll {
    $script:Tool = Join-Path $PSScriptRoot '../tools/Test-PublicContent.ps1'
    $script:Pwsh = (Get-Process -Id $PID).Path
    # Fixtures are built at runtime so this tracked file stays clean.
    $script:Mail = 'a.b' + '@' + 'example.org'
    $script:Guid = '1b2c3d4e-0000-4000-8000-' + '123456789abc'
    $script:ReaderGuid = 'acdd72a7-3385-48ef-' + 'bd42-f606fba81ae7'

    function script:Invoke-Tool {
        param([string[]]$Path, [string]$DenyListPath, [string]$AllowListPath)
        $toolArgs = @('-NoProfile', '-File', $script:Tool)
        if ($Path) { $toolArgs += @('-Path') + $Path }
        if ($DenyListPath) { $toolArgs += @('-DenyListPath', $DenyListPath) }
        if ($AllowListPath) { $toolArgs += @('-AllowListPath', $AllowListPath) }
        $out = & $script:Pwsh @toolArgs 2>&1 | Out-String
        [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
    }
    function script:New-Fixture {
        param([string]$Name, [string]$Text)
        $p = Join-Path $TestDrive $Name
        Set-Content -LiteralPath $p -Value $Text
        $p
    }
    $script:NoDeny = Join-Path $TestDrive 'no-deny.txt'
}

Describe 'Test-PublicContent' {
    It 'flags an e-mail address' {
        $f = New-Fixture 'mail.txt' "contact $script:Mail now"
        $r = Invoke-Tool -Path $f -DenyListPath $script:NoDeny
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'mail\.txt:1: e-mail'
    }
    It 'flags a GUID' {
        $f = New-Fixture 'guid.txt' "id $script:Guid"
        $r = Invoke-Tool -Path $f -DenyListPath $script:NoDeny
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'guid\.txt:1: guid'
    }
    It 'allows a listed built-in GUID' {
        $f = New-Fixture 'reader.txt' "Reader $script:ReaderGuid"
        $r = Invoke-Tool -Path $f -DenyListPath $script:NoDeny
        $r.Code | Should -Be 0
    }
    It 'flags a deny-list term case-insensitively' {
        $f = New-Fixture 'deny.txt' 'Contoso tenant'
        $d = New-Fixture 'deny-list.txt' "# comment`ncontoso"
        $r = Invoke-Tool -Path $f -DenyListPath $d
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'deny\.txt:1: deny-list'
    }
    It 'fails when no paths are given' {
        $r = Invoke-Tool -Path @() -DenyListPath $script:NoDeny
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'no files to check'
    }
    It 'fails on an empty path list' {
        $cmd = "& '$script:Tool' -Path @() -DenyListPath '$script:NoDeny'"
        $out = & $script:Pwsh -NoProfile -Command $cmd 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $out | Should -Match 'no files to check'
    }
    It 'reports a clean file' {
        $f = New-Fixture 'clean.txt' 'nothing to see'
        $r = Invoke-Tool -Path $f -DenyListPath $script:NoDeny
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'clean \(1 files\)'
    }
    It 'fails when a path does not exist' {
        $r = Invoke-Tool -Path (Join-Path $TestDrive 'missing.txt') -DenyListPath $script:NoDeny
        $r.Code | Should -Be 1
    }
    It 'skips binary files' {
        $p = Join-Path $TestDrive 'bin.dat'
        [IO.File]::WriteAllBytes($p, [byte[]](0, 1, 2) + [Text.Encoding]::ASCII.GetBytes($script:Mail))
        $r = Invoke-Tool -Path $p -DenyListPath $script:NoDeny
        $r.Code | Should -Be 0
    }
    It 'flags an e-mail in a UTF-16 LE file' {
        $p = Join-Path $TestDrive 'u16le.txt'
        [IO.File]::WriteAllText($p, "contact $script:Mail", [Text.UnicodeEncoding]::new($false, $true))
        $r = Invoke-Tool -Path $p -DenyListPath $script:NoDeny
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'u16le\.txt:1: e-mail'
    }
    It 'flags a GUID in a UTF-16 BE file' {
        $p = Join-Path $TestDrive 'u16be.txt'
        [IO.File]::WriteAllText($p, "id $script:Guid", [Text.UnicodeEncoding]::new($true, $true))
        $r = Invoke-Tool -Path $p -DenyListPath $script:NoDeny
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'u16be\.txt:1: guid'
    }
    It 'still skips a binary file without BOM' {
        $p = Join-Path $TestDrive 'nobom.dat'
        [IO.File]::WriteAllBytes($p, [byte[]](1, 0, 2, 0) + [Text.Encoding]::ASCII.GetBytes($script:Mail))
        $r = Invoke-Tool -Path $p -DenyListPath $script:NoDeny
        $r.Code | Should -Be 0
    }
    It 'flags an e-mail in the allow-list file' {
        $p = New-Fixture 'allow.txt' "# note $script:Mail`n$script:ReaderGuid"
        $r = Invoke-Tool -Path $p -DenyListPath $script:NoDeny -AllowListPath $p
        $r.Code | Should -Be 1
        $r.Output | Should -Match 'allow\.txt:1: e-mail'
        $r.Output | Should -Not -Match 'allow\.txt:2'
    }
}

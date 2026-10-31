BeforeAll {
    $script:Tool = Join-Path $PSScriptRoot '../tools/Test-PublicContent.ps1'
    $script:Pwsh = (Get-Process -Id $PID).Path
    # Fixtures are built at runtime so this tracked file stays clean.
    $script:Mail = 'a.b' + '@' + 'example.org'
    $script:Guid = '1b2c3d4e-0000-4000-8000-' + '123456789abc'
    $script:ReaderGuid = 'acdd72a7-3385-48ef-' + 'bd42-f606fba81ae7'

    function script:Invoke-Tool {
        param([string[]]$Path, [string]$DenyListPath)
        $toolArgs = @('-NoProfile', '-File', $script:Tool)
        if ($Path) { $toolArgs += @('-Path') + $Path }
        if ($DenyListPath) { $toolArgs += @('-DenyListPath', $DenyListPath) }
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
    It 'reports clean on empty repo' {
        $r = Invoke-Tool -Path @() -DenyListPath $script:NoDeny
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'clean'
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
}

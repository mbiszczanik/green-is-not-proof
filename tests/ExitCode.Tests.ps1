BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
}

Describe 'script exit codes' {
    It 'no script ends with SetShouldExit, which would close an interactive terminal' {
        # One exemption: the demo 4 validator is only ever run in a child process by Invoke-Gate.ps1, and SetShouldExit is the fix that demo shows.
        $exempt = [IO.Path]::GetFullPath((Join-Path $script:Root 'demos/4-gate-never-red/Test-Lab.Fixed.ps1'))
        $files = Get-ChildItem -Path (Join-Path $script:Root 'scripts'), (Join-Path $script:Root 'demos'), (Join-Path $script:Root 'tools') -Recurse -Filter *.ps1 |
            Where-Object { [IO.Path]::GetFullPath($_.FullName) -ne $exempt }
        $hits = @($files | Select-String -Pattern 'SetShouldExit' | ForEach-Object { "$($_.Path):$($_.LineNumber)" })
        $hits | Should -BeNullOrEmpty
    }

    It 'a failing script still gives process exit code 1 with a plain exit' {
        $out = Join-Path $TestDrive 'out'
        $null = & $script:Pwsh -NoProfile -File (Join-Path $script:Root 'scripts/Stop-DemoRun.ps1') -RunId bad -OutDir $out 2>&1
        $LASTEXITCODE | Should -Be 1
    }
}

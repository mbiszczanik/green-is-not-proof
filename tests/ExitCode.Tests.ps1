BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Pwsh = (Get-Process -Id $PID).Path
}

Describe 'script exit codes' {
    It 'no script ends with SetShouldExit, which would close an interactive terminal' {
        $files = Get-ChildItem -Path (Join-Path $script:Root 'scripts'), (Join-Path $script:Root 'demos'), (Join-Path $script:Root 'tools') -Recurse -Filter *.ps1
        $hits = @($files | Select-String -Pattern 'SetShouldExit' | ForEach-Object { "$($_.Path):$($_.LineNumber)" })
        $hits | Should -BeNullOrEmpty
    }

    It 'a failing script still gives process exit code 1 with a plain exit' {
        $out = Join-Path $TestDrive 'out'
        $null = & $script:Pwsh -NoProfile -File (Join-Path $script:Root 'scripts/Stop-DemoRun.ps1') -RunId bad -OutDir $out 2>&1
        $LASTEXITCODE | Should -Be 1
    }
}

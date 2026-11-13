<#
.SYNOPSIS
Runs every offline demo (2, the stub half of 3, 4, 6 and 7) and prints, per demo, the green result and the reveal.
.DESCRIPTION
Needs no Azure access and makes no network call. Each step runs in a child pwsh process; its exit code and output are
compared with what the demo README states. A demo whose prerequisite is missing is not run and is reported as NOT RUN
with the prerequisite named; the other demos still run. A demo whose step ends with another exit code, without the
expected line, or cannot start is reported as FAILED. Exit code: 0 only when every demo ran and matched, 1 otherwise.
The exercises are in docs/student-pack/exercises.md.
.EXAMPLE
pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1; $LASTEXITCODE
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

function Get-OfflineDemo {
    <#
    .SYNOPSIS
    Returns the offline demos: what each needs, the steps to run and what each step must show.
    .EXAMPLE
    Get-OfflineDemo -Root .
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param([Parameter(Mandatory)][string]$Root)
    $d2 = Join-Path $Root 'demos/2-dry-run-is-not-safe'
    $d3 = Join-Path $Root 'demos/3-stub-proves-assumption'
    $g4 = Join-Path $Root 'demos/4-gate-never-red/Invoke-Gate.ps1'
    $g6 = Join-Path $Root 'demos/6-lint-warns-gate-passes/Invoke-Gate.ps1'
    $g7 = Join-Path $Root 'demos/7-unprocessed-object-passes/Invoke-Gate.ps1'
    @(
        @{
            Id = '2'; Title = 'dry-run is not safe'; Needs = @('Pester')
            Steps = @(
                @{
                    Label = 'Green'; Kind = 'Text'; Target = ''; Arguments = @(); ExpectExit = 0; ExpectText = @()
                    Say = 'no command. The green is the -DryRun switch of Deploy-Example.ps1: its deployment call sits behind the switch.'
                }
                @{
                    Label = 'Reveal'; Kind = 'Pester'; Target = $d2; Arguments = @(); ExpectExit = 1
                    ExpectText = @('Tests Passed: 1, Failed: 1', '\[-\] .*Deploy-Example\.ps1 has no unguarded mutation')
                    Say = 'the syntax-tree test is red for Deploy-Example.ps1 (a call above the guard) and green for Deploy-Example.Fixed.ps1.'
                }
            )
        }
        @{
            Id = '3'; Title = 'a stubbed test checks only your assumption (stub half)'; Needs = @('Pester')
            Steps = @(
                @{
                    Label = 'Green'; Kind = 'Pester'; Target = $d3; Arguments = @(); ExpectExit = 0
                    ExpectText = @('Tests Passed: 1, Failed: 0')
                    Say = 'the stubbed suite passes.'
                }
                @{
                    Label = 'Reveal'; Kind = 'Text'; Target = ''; Arguments = @(); ExpectExit = 0; ExpectText = @()
                    Say = 'not run here, it needs Azure. The demo README records the live read: PrivateLinkScopedResources: (empty), ProvisioningState: Succeeded, Strict health: False.'
                }
            )
        }
        @{
            Id = '4'; Title = 'a gate you never saw red'; Needs = @('Pester')
            Steps = @(
                @{
                    Label = 'Green'; Kind = 'Script'; Target = $g4; Arguments = @('-Script', 'Silent', '-State', 'Empty'); ExpectExit = 0
                    ExpectText = @('The gate would PASS although the output shows a failure\.')
                    Say = 'the validator prints [FAIL] lines and its process exits 0.'
                }
                @{
                    Label = 'Reveal'; Kind = 'Script'; Target = $g4; Arguments = @('-Script', 'Fixed', '-State', 'Empty'); ExpectExit = 1
                    ExpectText = @('Process exit code: 1')
                    Say = 'the fixed validator exits 1 on the same input.'
                }
            )
        }
        @{
            Id = '6'; Title = 'a gate that reads only the exit code'; Needs = @('Bicep CLI')
            Steps = @(
                @{
                    Label = 'Green'; Kind = 'Script'; Target = $g6; Arguments = @('-Gate', 'Bare', '-Template', 'Sample'); ExpectExit = 0
                    ExpectText = @('The gate would PASS although the output shows a diagnostic\.')
                    Say = 'the linter prints a Warning and the bare gate passes.'
                }
                @{
                    Label = 'Reveal'; Kind = 'Script'; Target = $g6; Arguments = @('-Gate', 'Fixed', '-Template', 'Sample'); ExpectExit = 1
                    ExpectText = @('Fixed gate: FAIL')
                    Say = 'the fixed gate also reads the output and fails on the same template.'
                }
            )
        }
        @{
            Id = '7'; Title = 'a gate that passes when nothing was evaluated'; Needs = @('PSRule')
            Steps = @(
                @{
                    Label = 'Green'; Kind = 'Script'; Target = $g7; Arguments = @('-Gate', 'Bare', '-Pipeline', 'Misconfigured'); ExpectExit = 0
                    ExpectText = @('The gate would PASS although no rule was evaluated\.')
                    Say = 'Assert-PSRule exits 0 on an insecure template and the bare gate passes.'
                }
                @{
                    Label = 'Reveal'; Kind = 'Script'; Target = $g7; Arguments = @('-Gate', 'Fixed', '-Pipeline', 'Misconfigured'); ExpectExit = 1
                    ExpectText = @('Fixed gate: FAIL')
                    Say = 'the fixed gate also reads how many rules were evaluated and fails on zero.'
                }
            )
        }
    )
}

function Test-PackPrerequisite {
    <#
    .SYNOPSIS
    True when the named prerequisite is available on this machine.
    .EXAMPLE
    Test-PackPrerequisite -Name 'Bicep CLI'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][ValidateSet('PowerShell 7', 'Pester', 'Bicep CLI', 'PSRule')][string]$Name)
    switch ($Name) {
        'PowerShell 7' { return ($PSVersionTable.PSVersion.Major -ge 7) }
        'Pester' { return [bool](Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.5' }) }
        # Demo 6 uses bicep, else az bicep.
        'Bicep CLI' { return ([bool](Get-Command bicep -ErrorAction SilentlyContinue) -or [bool](Get-Command az -ErrorAction SilentlyContinue)) }
        'PSRule' { return ([bool](Get-Module -ListAvailable PSRule) -and [bool](Get-Module -ListAvailable PSRule.Rules.Azure)) }
    }
}

function Invoke-PackStep {
    <#
    .SYNOPSIS
    Runs one step in a child pwsh process and returns its exit code and output lines.
    .EXAMPLE
    $r = Invoke-PackStep -Step $step
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][hashtable]$Step)
    $pwsh = (Get-Process -Id $PID).Path
    if ($Step.Kind -eq 'Pester') {
        $path = $Step.Target.Replace("'", "''")
        # The exit code is the number of failures, so a red suite is read from the process, not from the text.
        $cmd = "Import-Module Pester -MinimumVersion 5.5; `$c = New-PesterConfiguration; `$c.Run.Path = '$path'; " +
            "`$c.Run.PassThru = `$true; `$c.Output.Verbosity = 'Detailed'; `$r = Invoke-Pester -Configuration `$c; " +
            "exit (`$r.FailedCount + `$r.FailedBlocksCount + `$r.FailedContainersCount)"
        $lines = @(& $pwsh -NoProfile -Command $cmd 2>&1 | ForEach-Object { "$_" })
    }
    else {
        $arguments = @($Step.Arguments)
        $lines = @(& $pwsh -NoProfile -File $Step.Target @arguments 2>&1 | ForEach-Object { "$_" })
    }
    $code = $LASTEXITCODE
    # Colour codes would break the comparison with the expected lines.
    $plain = @($lines | ForEach-Object { $_ -replace "$([char]27)\[[0-9;]*m", '' })
    [pscustomobject]@{ Code = $code; Line = $plain }
}

function Invoke-OfflinePack {
    <#
    .SYNOPSIS
    Runs the offline demos and prints the result of each; returns 0 when every demo ran and matched, else 1.
    .EXAMPLE
    $code = Invoke-OfflinePack -Root .
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory)][string]$Root)
    $ok = @()
    $notRun = @()
    $failed = @()
    $demos = @(Get-OfflineDemo -Root $Root)
    if (-not (Test-PackPrerequisite -Name 'PowerShell 7')) {
        Write-Host 'Missing prerequisite: PowerShell 7. No demo was run.'
        foreach ($d in $demos) { $notRun += "demo $($d.Id) (missing: PowerShell 7)" }
        $demos = @()
    }
    foreach ($d in $demos) {
        Write-Host ''
        Write-Host "== Demo $($d.Id): $($d.Title)"
        $missing = @($d.Needs | Where-Object { -not (Test-PackPrerequisite -Name $_) })
        if ($missing.Count -gt 0) {
            Write-Host "NOT RUN: demo $($d.Id) needs $($missing -join ', '), which is missing."
            $notRun += "demo $($d.Id) (missing: $($missing -join ', '))"
            continue
        }
        $why = ''
        foreach ($s in $d.Steps) {
            Write-Host "-- $($s.Label): $($s.Say)"
            if ($s.Kind -eq 'Text') { continue }
            try { $r = Invoke-PackStep -Step $s }
            catch { $why = "step $($s.Label) could not start: $($_.Exception.Message)"; break }
            foreach ($l in @($r.Line)) { Write-Host ('   ' + "$l".Replace($Root, '.')) }
            Write-Host "   Exit code: $($r.Code) (expected $($s.ExpectExit))"
            if ($r.Code -ne $s.ExpectExit) { $why = "step $($s.Label) ended with exit code $($r.Code), expected $($s.ExpectExit)"; break }
            $text = @($r.Line) -join "`n"
            $absent = @($s.ExpectText | Where-Object { $text -notmatch $_ })
            if ($absent.Count -gt 0) { $why = "step $($s.Label) did not print the expected line ($($absent[0]))"; break }
        }
        if ($why) {
            Write-Host "FAILED: demo $($d.Id): $why"
            $failed += "demo $($d.Id) ($why)"
        }
        else {
            Write-Host "OK: demo $($d.Id) showed its green and its reveal."
            $ok += "demo $($d.Id)"
        }
    }
    Write-Host ''
    Write-Host "Offline pack: $($ok.Count) ok, $($notRun.Count) not run, $($failed.Count) failed"
    foreach ($n in $notRun) { Write-Host "Not run: $n" }
    foreach ($f in $failed) { Write-Host "Failed: $f" }
    if ($notRun.Count -gt 0 -or $failed.Count -gt 0) { return 1 }
    Write-Host 'Next: docs/student-pack/exercises.md'
    0
}

if ($MyInvocation.InvocationName -ne '.') {
    $code = Invoke-OfflinePack -Root ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')))
    exit $code
}

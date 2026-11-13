<#
.SYNOPSIS
Runs every offline demo (2, 3 stub half, 4, 6, 7) and prints, per demo, the green result and the reveal. Needs no Azure access.
.DESCRIPTION
Each demo is run through its own scripts in child processes. A demo passes only when every command exits with the
exit code the demo documents and prints every line the pack expects, so a demo that stops showing its point fails
instead of passing. The green result, the reveal and the fix are printed as the lines found in the output.
If a prerequisite (PowerShell 7, Pester, the Bicep CLI, PSRule, PSRule.Rules.Azure) is missing, the pack names it,
skips only that demo and reports it as NOT RUN. Exit code: 0 when every selected demo passed, else 1; a demo that is not
run or fails to run counts as a failure. Exercises and answer keys are under docs/student-pack/.
.PARAMETER Demo
Run only these demos (2, 3, 4, 6, 7), as a comma-separated list under -File: -Demo 2,4. Default: all of them. An unknown id exits 1.
.EXAMPLE
pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1; $LASTEXITCODE
.EXAMPLE
pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1 -Demo 4
#>
[CmdletBinding()]
param([string[]]$Demo)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../lib/ToolVersion.ps1

function Get-OfflineDemo {
    <#
    .SYNOPSIS
    Returns the offline demos: id, title, required tools and the steps to run, each with the lines it must print.
    .DESCRIPTION
    A step runs one command and expects one exit code. Show holds the lines the output must contain (case-sensitive
    regex), each with the role it plays: Green, Reveal or Fix.
    .EXAMPLE
    Get-OfflineDemo -Root (Get-Location).Path
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param([Parameter(Mandatory)][string]$Root)
    $health = (Join-Path $Root 'demos/3-stub-proves-assumption/Test-WorkspaceHealth.ps1').Replace("'", "''")
    @(
        @{ Id = '2'; Title = 'dry-run is not safe'; Requires = @('Pester'); Steps = @(
                @{ Label = 'syntax-tree test over both example scripts'; Kind = 'Pester'; Target = 'demos/2-dry-run-is-not-safe'; ExpectExit = 0; Show = @(
                        @{ Role = 'Green'; Pattern = '^\[PASS\] Deploy-Example\.Fixed\.ps1 has no unguarded mutation' }
                        @{ Role = 'Reveal'; Pattern = '^\[FAIL\] Deploy-Example\.ps1 has no unguarded mutation: .*line \d+: Register-AzResourceProvider' }
                    ) }
            ) }
        @{ Id = '3'; Title = 'a stubbed test checks only your assumption (stub half)'; Requires = @('Pester'); Steps = @(
                @{ Label = 'stubbed health suite'; Kind = 'Pester'; Target = 'demos/3-stub-proves-assumption'; ExpectExit = 0; Show = @(
                        @{ Role = 'Green'; Pattern = '^\[PASS\] passes for a stub object that has the property filled in' }
                    ) }
                @{ Label = 'same check on an object shaped like the live read recorded in the README (constructed, not a live read)'; Kind = 'Command'
                    Code = ". '$health'; `$ws = [pscustomobject]@{ ProvisioningState = 'Succeeded'; PrivateLinkScopedResources = @() }; 'Strict health: ' + (Test-WorkspaceHealth -Workspace `$ws)"
                    ExpectExit = 0; Show = @(@{ Role = 'Reveal'; Pattern = '^Strict health: False$' }) }
            ) }
        @{ Id = '4'; Title = 'a gate you never saw red'; Requires = @('Pester'); Steps = @(
                @{ Label = 'validator that never sets an exit code'; Kind = 'Script'; Target = 'demos/4-gate-never-red/Invoke-Gate.ps1'; Args = @('-Script', 'Silent', '-State', 'Empty'); ExpectExit = 0; Show = @(
                        @{ Role = 'Green'; Pattern = '^Process exit code: 0$' }
                        @{ Role = 'Reveal'; Pattern = '^The gate would PASS although the output shows a failure\.$' }
                    ) }
                @{ Label = 'validator that calls exit 1 under #Requires'; Kind = 'Script'; Target = 'demos/4-gate-never-red/Invoke-Gate.ps1'; Args = @('-Script', 'Counted', '-State', 'Empty'); ExpectExit = 0; Show = @(
                        @{ Role = 'Reveal'; Pattern = '^Validation complete: 2 failed\.$' }
                        @{ Role = 'Reveal'; Pattern = '^Process exit code: 0$' }
                    ) }
                @{ Label = 'fixed validator, empty state'; Kind = 'Script'; Target = 'demos/4-gate-never-red/Invoke-Gate.ps1'; Args = @('-Script', 'Fixed', '-State', 'Empty'); ExpectExit = 1; Show = @(
                        @{ Role = 'Fix'; Pattern = '^Process exit code: 1$' }
                    ) }
                @{ Label = 'fixed validator, complete state'; Kind = 'Script'; Target = 'demos/4-gate-never-red/Invoke-Gate.ps1'; Args = @('-Script', 'Fixed', '-State', 'Ok'); ExpectExit = 0; Show = @(
                        @{ Role = 'Fix'; Pattern = '^Process exit code: 0$' }
                    ) }
            ) }
        @{ Id = '6'; Title = 'a gate that reads only the exit code'; Requires = @('Bicep CLI'); Steps = @(
                @{ Label = 'bare gate on Sample.bicep'; Kind = 'Script'; Target = 'demos/6-lint-warns-gate-passes/Invoke-Gate.ps1'; Args = @('-Gate', 'Bare', '-Template', 'Sample'); ExpectExit = 0; Show = @(
                        @{ Role = 'Green'; Pattern = '^Bare gate: PASS$' }
                        @{ Role = 'Reveal'; Pattern = '^Warning or Error lines in the output: 1$' }
                        @{ Role = 'Reveal'; Pattern = '^The gate would PASS although the output shows a diagnostic\.$' }
                    ) }
                @{ Label = 'fixed gate on Sample.bicep'; Kind = 'Script'; Target = 'demos/6-lint-warns-gate-passes/Invoke-Gate.ps1'; Args = @('-Gate', 'Fixed', '-Template', 'Sample'); ExpectExit = 1; Show = @(
                        @{ Role = 'Fix'; Pattern = '^Fixed gate: FAIL$' }
                    ) }
            ) }
        @{ Id = '7'; Title = 'a gate that passes when nothing was evaluated'; Requires = @('PSRule', 'PSRule.Rules.Azure'); Steps = @(
                @{ Label = 'bare gate, Bicep expansion off'; Kind = 'Script'; Target = 'demos/7-unprocessed-object-passes/Invoke-Gate.ps1'; Args = @('-Gate', 'Bare', '-Pipeline', 'Misconfigured'); ExpectExit = 0; Show = @(
                        @{ Role = 'Green'; Pattern = '^Bare gate: PASS$' }
                        @{ Role = 'Reveal'; Pattern = 'Rules processed: 0, failed: 0, errored: 0' }
                        @{ Role = 'Reveal'; Pattern = '^The gate would PASS although no rule was evaluated\.$' }
                    ) }
                @{ Label = 'fixed gate, Bicep expansion off'; Kind = 'Script'; Target = 'demos/7-unprocessed-object-passes/Invoke-Gate.ps1'; Args = @('-Gate', 'Fixed', '-Pipeline', 'Misconfigured'); ExpectExit = 1; Show = @(
                        @{ Role = 'Fix'; Pattern = '^Fixed gate: FAIL$' }
                    ) }
            ) }
    )
}

function Invoke-PackStep {
    <#
    .SYNOPSIS
    Runs one step in a child process and returns its exit code and output lines.
    .DESCRIPTION
    A Pester step runs the suite in the child and reports each test as a [PASS] or [FAIL] line, with the failure
    message on the same line; the child exits 0 when the suite ran, whatever the tests did.
    .EXAMPLE
    Invoke-PackStep -Step $step -Root (Get-Location).Path
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][hashtable]$Step, [Parameter(Mandatory)][string]$Root)
    $pwsh = (Get-Process -Id $PID).Path
    switch ($Step.Kind) {
        'Script' {
            $extra = @($Step.Args)
            $lines = @(& $pwsh -NoProfile -File (Join-Path $Root $Step.Target) @extra 2>&1 | ForEach-Object { "$_" })
            return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Line = $lines }
        }
        'Command' {
            $lines = @(& $pwsh -NoProfile -Command $Step.Code 2>&1 | ForEach-Object { "$_" })
            return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Line = $lines }
        }
        'Pester' {
            $path = (Join-Path $Root $Step.Target).Replace("'", "''")
            $code = @"
`$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.5
`$c = New-PesterConfiguration
`$c.Run.Path = '$path'; `$c.Run.PassThru = `$true; `$c.Output.Verbosity = 'None'
`$r = Invoke-Pester -Configuration `$c
`$o = foreach (`$t in `$r.Tests) { [pscustomobject]@{ Name = `$t.Name; Result = `$t.Result; Message = ((`$t.ErrorRecord | ForEach-Object { `$_.Exception.Message }) -join ' ' -replace '\s+', ' ') } }
'PACKRESULT ' + (ConvertTo-Json -InputObject @(`$o) -Compress)
"@
            $out = @(& $pwsh -NoProfile -Command $code 2>&1 | ForEach-Object { "$_" })
            $exit = $LASTEXITCODE
            $marker = @($out | Where-Object { $_ -cmatch '^PACKRESULT ' })
            if ($exit -ne 0 -or $marker.Count -ne 1) {
                return [pscustomobject]@{ ExitCode = $(if ($exit -ne 0) { $exit } else { 1 }); Line = @($out) + 'The Pester run produced no result.' }
            }
            $tests = @(($marker[0] -replace '^PACKRESULT ', '') | ConvertFrom-Json)
            $lines = @($out | Where-Object { $_ -cnotmatch '^PACKRESULT ' })
            foreach ($t in $tests) {
                if ($t.Result -eq 'Passed') { $lines += "[PASS] $($t.Name)" } else { $lines += "[FAIL] $($t.Name): $($t.Message)" }
            }
            return [pscustomobject]@{ ExitCode = 0; Line = $lines }
        }
        default { throw "Unknown step kind '$($Step.Kind)'." }
    }
}

function Test-PackStep {
    <#
    .SYNOPSIS
    Returns one problem string per way a step result differs from what the demo documents; empty means it matches.
    .EXAMPLE
    Test-PackStep -Step $step -Result $result
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)][hashtable]$Step, [Parameter(Mandatory)][pscustomobject]$Result)
    $problems = @()
    if ($Result.ExitCode -ne $Step.ExpectExit) { $problems += "exit code $($Result.ExitCode), expected $($Step.ExpectExit)" }
    foreach ($s in $Step.Show) {
        if (-not @($Result.Line | Where-Object { $_ -cmatch $s.Pattern }).Count) { $problems += "no output line matches '$($s.Pattern)'" }
    }
    $problems
}

function Invoke-OfflinePack {
    <#
    .SYNOPSIS
    Runs the demos, prints the green result and the reveal of each and returns the outcome per demo and the exit code.
    .DESCRIPTION
    GetVersion answers a tool name with its version, or '' when it is missing. Runner runs one step and returns an
    object with ExitCode and Line. Both are parameters so a test can replace them.
    .EXAMPLE
    Invoke-OfflinePack -Demo (Get-OfflineDemo -Root $root) -GetVersion { param($n) Get-DemoToolVersion -Name $n } -Runner { param($s) Invoke-PackStep -Step $s -Root $root }
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][hashtable[]]$Demo,
        [Parameter(Mandatory)][scriptblock]$GetVersion,
        [Parameter(Mandatory)][scriptblock]$Runner
    )
    $results = @()
    foreach ($d in $Demo) {
        Write-Host "== Demo $($d.Id): $($d.Title)"
        $missing = @($d.Requires | Where-Object { -not (& $GetVersion $_) })
        if ($missing.Count -gt 0) {
            Write-Host "NOT RUN: missing $($missing -join ', ')"
            $results += [pscustomobject]@{ Id = $d.Id; Status = 'NotRun'; Detail = "missing $($missing -join ', ')" }
            continue
        }
        $problems = @()
        foreach ($step in $d.Steps) {
            try { $r = & $Runner $step }
            catch { $r = [pscustomobject]@{ ExitCode = 1; Line = @("The step threw: $($_.Exception.Message)") } }
            $p = @(Test-PackStep -Step $step -Result $r)
            Write-Host "Run:    $($step.Label) (exit $($r.ExitCode))"
            if ($p.Count -gt 0) {
                $problems += $p | ForEach-Object { "$($step.Label): $_" }
                Write-Host "FAILED: $($p -join '; ')"
                @($r.Line | Select-Object -First 30) | ForEach-Object { Write-Host "        $_" }
                continue
            }
            foreach ($s in $step.Show) {
                $line = @($r.Line | Where-Object { $_ -cmatch $s.Pattern })[0]
                Write-Host ("{0,-7} {1}" -f "$($s.Role):", $line.Trim())
            }
        }
        $pass = $problems.Count -eq 0
        $n = $d.Id
        Write-Host "Exercise: docs/student-pack/exercises/demo-$n.md (answer key: docs/student-pack/answers/demo-$n.md)"
        $results += [pscustomobject]@{ Id = $d.Id; Status = $(if ($pass) { 'Passed' } else { 'Failed' }); Detail = ($problems -join '; ') }
    }
    $passed = @($results | Where-Object Status -EQ 'Passed').Count
    $failed = @($results | Where-Object Status -EQ 'Failed').Count
    $notRun = @($results | Where-Object Status -EQ 'NotRun').Count
    Write-Host ''
    foreach ($r in $results) {
        $text = switch ($r.Status) { 'Passed' { 'PASSED' } 'Failed' { "FAILED ($($r.Detail))" } default { "NOT RUN ($($r.Detail))" } }
        Write-Host "Demo $($r.Id): $text"
    }
    Write-Host "Offline pack: $passed passed, $failed failed, $notRun not run."
    $exit = if ($results.Count -gt 0 -and $failed -eq 0 -and $notRun -eq 0) { 0 } else { 1 }
    [pscustomobject]@{ Results = $results; ExitCode = $exit }
}

if ($MyInvocation.InvocationName -ne '.') {
    $root = Split-Path -Parent $PSScriptRoot
    $all = @(Get-OfflineDemo -Root $root)
    if ($Demo) {
        $ids = @($Demo | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() })
        $unknown = @($ids | Where-Object { $_ -notin $all.Id })
        if ($unknown.Count -gt 0) { Write-Host "Unknown demo: $($unknown -join ', '). Offline demos: $($all.Id -join ', ')."; exit 1 }
        $all = @($all | Where-Object { $_.Id -in $ids })
    }
    $run = Invoke-OfflinePack -Demo $all -GetVersion { param($Name) Get-DemoToolVersion -Name $Name } -Runner { param($Step) Invoke-PackStep -Step $Step -Root $root }
    exit $run.ExitCode
}

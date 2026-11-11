<#
.SYNOPSIS
Runs Pester over a path and exits 1 unless every discovered test, block and container completed and passed, with no unlisted skip.
.DESCRIPTION
The CI gate for the test suite. Rejects a null result, a result other than Passed, failed tests, failed blocks,
failed containers, tests not run, inconclusive tests, and a run with zero tests. A skipped test is rejected unless
it is on the allowlist (tools/ci-skip-allow.txt, one `<test path> | <reason>` per line, # comments); an entry
without a reason is rejected. A file that throws during discovery is a failed container, so another file's passing
test cannot hide it. Prints the counts, including skipped, and one decision line, and exits 0 or 1.
.PARAMETER AllowSkipPath
Allowlist of tests that may be skipped. A missing default file is an empty allowlist; a missing named file is an error.
.EXAMPLE
./tools/Invoke-CiPester.ps1 -Path ./tests
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [ValidateSet('None', 'Normal', 'Detailed')][string]$Output = 'Normal',
    [string]$AllowSkipPath
)
# No strict mode or Stop preference at script scope: Pester runs the tests in this scope and they would inherit it.

function Read-SkipAllowlist {
    <#
    .SYNOPSIS
    Reads the skip allowlist; returns the allowed test paths with reasons and any problems found.
    .EXAMPLE
    Read-SkipAllowlist -Path ./tools/ci-skip-allow.txt
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [switch]$Required)
    Set-StrictMode -Version Latest
    $allowed = @{}
    $problems = @()
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($Required) { $problems += "skip allowlist $Path not found" }
        return [pscustomobject]@{ Allowed = $allowed; Problems = $problems }
    }
    foreach ($raw in @(Get-Content -LiteralPath $Path)) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $name, $reason = ($line -split '\|', 2).ForEach({ $_.Trim() })
        if (-not $reason) { $problems += "allowlist entry without a reason: $line"; continue }
        $allowed[$name] = $reason
    }
    [pscustomobject]@{ Allowed = $allowed; Problems = $problems }
}

function Get-PesterDecision {
    <#
    .SYNOPSIS
    Returns the reasons a Pester result must be rejected; an empty array means accept.
    .EXAMPLE
    Get-PesterDecision -Result (Invoke-Pester -Path ./tests -PassThru)
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param($Result, [hashtable]$Allowed = @{}, [string[]]$AllowProblems = @())
    Set-StrictMode -Version Latest
    if ($null -eq $Result) { return @('no result') }
    $why = @()
    if ($Result.Result -ne 'Passed') { $why += "result is $($Result.Result)" }
    if ($Result.FailedCount -gt 0) { $why += "$($Result.FailedCount) failed test(s)" }
    if ($Result.FailedBlocksCount -gt 0) { $why += "$($Result.FailedBlocksCount) failed block(s)" }
    if ($Result.FailedContainersCount -gt 0) { $why += "$($Result.FailedContainersCount) failed container(s)" }
    if ($Result.NotRunCount -gt 0) { $why += "$($Result.NotRunCount) test(s) not run" }
    if ($Result.TotalCount -eq 0) { $why += 'no tests ran' }
    if ($Result.InconclusiveCount -gt 0) { $why += "$($Result.InconclusiveCount) inconclusive test(s)" }
    $why += $AllowProblems
    $skipped = @($Result.Tests | Where-Object { $_.Result -eq 'Skipped' } | ForEach-Object { $_.ExpandedPath })
    if ($skipped.Count -ne $Result.SkippedCount) { $why += "skipped count $($Result.SkippedCount) does not match the $($skipped.Count) skipped tests listed" }
    $unlisted = @($skipped | Where-Object { -not $Allowed.ContainsKey($_) })
    if ($unlisted.Count -gt 0) { $why += "$($unlisted.Count) skipped test(s) not on the allowlist: $($unlisted -join ', ')" }
    return $why
}

if ($MyInvocation.InvocationName -ne '.') {
    $cfg = New-PesterConfiguration
    $cfg.Run.Path = $Path
    $cfg.Run.PassThru = $true
    $cfg.Output.Verbosity = $Output
    $list = if ($AllowSkipPath) { Read-SkipAllowlist -Path $AllowSkipPath -Required } else { Read-SkipAllowlist -Path (Join-Path $PSScriptRoot 'ci-skip-allow.txt') }
    $result = Invoke-Pester -Configuration $cfg
    $why = @(Get-PesterDecision -Result $result -Allowed $list.Allowed -AllowProblems $list.Problems)
    if ($null -ne $result) {
        $skippedNow = @($result.Tests | Where-Object { $_.Result -eq 'Skipped' } | ForEach-Object { $_.ExpandedPath })
        $listed = @($skippedNow | Where-Object { $list.Allowed.ContainsKey($_) }).Count
        $evaluated = $result.PassedCount + $result.FailedCount
        Write-Host "Pester counts: $($result.TotalCount) total, $($result.PassedCount) passed, $($result.FailedCount) failed, $($result.SkippedCount) skipped ($listed allowlisted), $evaluated evaluated"
        foreach ($n in $list.Allowed.Keys | Where-Object { $_ -notin $skippedNow }) { Write-Host "note: allowlisted but not skipped: $n" }
    }
    if ($why.Count -gt 0) {
        Write-Host "Pester rejected: $($why -join '; ')"
        exit 1
    }
    Write-Host 'Pester accepted: every test, block and container completed and passed, and every skip is allowlisted'
}

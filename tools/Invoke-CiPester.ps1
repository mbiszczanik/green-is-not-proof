<#
.SYNOPSIS
Runs Pester over a path and exits 1 unless every discovered test, block and container completed and passed.
.DESCRIPTION
The CI gate for the test suite. Rejects a null result, a result other than Passed, failed tests, failed blocks,
failed containers, tests not run, and a run with zero tests. A file that throws during discovery is a failed
container, so another file's passing test cannot hide it. Prints one decision line and exits 0 or 1.
.EXAMPLE
./tools/Invoke-CiPester.ps1 -Path ./tests
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [ValidateSet('None', 'Normal', 'Detailed')][string]$Output = 'Normal'
)
# No strict mode or Stop preference at script scope: Pester runs the tests in this scope and they would inherit it.

function Get-PesterDecision {
    <#
    .SYNOPSIS
    Returns the reasons a Pester result must be rejected; an empty array means accept.
    .EXAMPLE
    Get-PesterDecision -Result (Invoke-Pester -Path ./tests -PassThru)
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param($Result)
    Set-StrictMode -Version Latest
    if ($null -eq $Result) { return @('no result') }
    $why = @()
    if ($Result.Result -ne 'Passed') { $why += "result is $($Result.Result)" }
    if ($Result.FailedCount -gt 0) { $why += "$($Result.FailedCount) failed test(s)" }
    if ($Result.FailedBlocksCount -gt 0) { $why += "$($Result.FailedBlocksCount) failed block(s)" }
    if ($Result.FailedContainersCount -gt 0) { $why += "$($Result.FailedContainersCount) failed container(s)" }
    if ($Result.NotRunCount -gt 0) { $why += "$($Result.NotRunCount) test(s) not run" }
    if ($Result.TotalCount -eq 0) { $why += 'no tests ran' }
    return $why
}

if ($MyInvocation.InvocationName -ne '.') {
    $cfg = New-PesterConfiguration
    $cfg.Run.Path = $Path
    $cfg.Run.PassThru = $true
    $cfg.Output.Verbosity = $Output
    $why = @(Get-PesterDecision -Result (Invoke-Pester -Configuration $cfg))
    if ($why.Count -gt 0) {
        Write-Host "Pester rejected: $($why -join '; ')"
        exit 1
    }
    Write-Host 'Pester accepted: every test, block and container completed and passed'
}

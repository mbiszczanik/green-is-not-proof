<#
.SYNOPSIS
Demo 4: runs one validator as a separate process (`pwsh -File`) and prints what the process itself reports.
.DESCRIPTION
Prints the validator's output, then the process exit code and how many [FAIL] lines the output held. If the
exit code is 0 while the output shows a failure, it says so: the gate would pass. Exits with the validator's
exit code. Needs no Azure access.
.EXAMPLE
./demos/4-gate-never-red/Invoke-Gate.ps1 -Script Silent -State Empty
.EXAMPLE
./demos/4-gate-never-red/Invoke-Gate.ps1 -Script Fixed -State Empty
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Silent', 'Counted', 'Fixed')][string]$Script,
    [ValidateSet('Empty', 'Ok')][string]$State = 'Empty'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Gate {
    <#
    .SYNOPSIS
    Runs the validator script in a child pwsh process and returns its exit code, printing the evidence.
    .EXAMPLE
    $code = Invoke-Gate -ScriptPath ./Test-Lab.Fixed.ps1 -StatePath ./state-empty.json
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$StatePath
    )
    $pwsh = (Get-Process -Id $PID).Path
    $lines = @(& $pwsh -NoProfile -File $ScriptPath -StatePath $StatePath 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $lines | ForEach-Object { Write-Host $_ }
    $failLines = @($lines | Where-Object { $_ -match '^\[FAIL\]' }).Count
    Write-Host ''
    Write-Host "Process exit code: $code"
    Write-Host "Failure lines in the output: $failLines"
    if ($code -eq 0 -and $failLines -gt 0) { Write-Host 'The gate would PASS although the output shows a failure.' }
    $code
}

if ($MyInvocation.InvocationName -ne '.') {
    $stateFile = if ($State -eq 'Ok') { 'state-ok.json' } else { 'state-empty.json' }
    $code = Invoke-Gate -ScriptPath (Join-Path $PSScriptRoot "Test-Lab.$Script.ps1") -StatePath (Join-Path $PSScriptRoot $stateFile)
    exit $code
}

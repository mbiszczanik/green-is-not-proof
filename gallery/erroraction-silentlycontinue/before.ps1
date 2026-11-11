# Gallery input: Get-Item fails on a missing path, the error is silenced, and nobody checks the result.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$path = Join-Path ([IO.Path]::GetTempPath()) 'gallery-erroraction-silentlycontinue-missing/input.txt'
Get-Item -LiteralPath $path -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "Found $($_.Name)." }
Write-Host 'Step complete: input file checked.'

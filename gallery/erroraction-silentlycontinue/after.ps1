# Gallery input: the same call with -ErrorAction Stop; the failure is printed and the process exits 1.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$path = Join-Path ([IO.Path]::GetTempPath()) 'gallery-erroraction-silentlycontinue-missing/input.txt'
try {
    Get-Item -LiteralPath $path -ErrorAction Stop | ForEach-Object { Write-Host "Found $($_.Name)." }
}
catch {
    Write-Host "[FAIL] $($_.Exception.Message)"
    exit 1
}
Write-Host 'Step complete: input file checked.'

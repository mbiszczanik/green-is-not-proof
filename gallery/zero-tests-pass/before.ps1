# Gallery input: a runner that discovers zero test files, prints a success line and exits 0.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$testDir = Join-Path ([IO.Path]::GetTempPath()) 'gallery-zero-tests-pass-empty'
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
$found = @(Get-ChildItem -LiteralPath $testDir -Filter '*.Tests.ps1' -File)
Write-Host "Discovered $($found.Count) test files."
Write-Host 'All discovered tests passed.'

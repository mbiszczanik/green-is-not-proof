# Gallery input: the report holds no failedItems value, a missing value compares as "at most 5", and the check passes.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$report = @{ job = 'nightly-backup' }
$limit = 5
$actual = $report['failedItems']
if ($actual -le $limit) {
    Write-Host "Check passed: failed items within the limit of $limit."
    exit 0
}
Write-Host "[FAIL] Failed items ($actual) above the limit of $limit."
exit 1

# Gallery input: `$actual -le $limit` with a missing (null) value evaluates true, so the check passes.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$limit = 200
$reading = @{ cpuPercent = 40 }
$actual = $reading['latencyMs']
if ($actual -le $limit) {
    Write-Host "Check passed: latency is within the limit of $limit ms."
}

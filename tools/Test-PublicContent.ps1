<#
.SYNOPSIS
Fails when tracked files contain e-mail addresses, GUIDs or deny-listed terms.
.DESCRIPTION
Prints file:line: <kind> per hit and exits 1; otherwise prints a clean summary and exits 0.
GUIDs listed in tools/public-content-allow.txt (built-in Azure ids) are allowed. The deny list
(tenant and organisation names, one per line, # comments) is a local untracked file; if it is
missing, only e-mails and GUIDs are checked.
.EXAMPLE
./tools/Test-PublicContent.ps1 -Path (git ls-files)
#>
[CmdletBinding()]
param(
    [string[]]$Path = @(),
    [string]$DenyListPath = (Join-Path $HOME '.config/green-is-not-proof/deny.txt')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$allowFile = Join-Path $PSScriptRoot 'public-content-allow.txt'
$allowed = @{}
if (Test-Path -LiteralPath $allowFile) {
    foreach ($l in Get-Content -LiteralPath $allowFile) {
        $t = $l.Trim()
        if ($t -and -not $t.StartsWith('#')) { $allowed[$t.ToLowerInvariant()] = $true }
    }
}

$deny = @()
if (Test-Path -LiteralPath $DenyListPath) {
    $deny = @(Get-Content -LiteralPath $DenyListPath | ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#') })
}
else {
    Write-Warning "deny list not found at $DenyListPath; checking e-mails and GUIDs only"
}

$emailRx = [regex]'[\w.+-]+@[\w-]+\.[\w.-]+'
$guidRx = [regex]'[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}'
$allowFull = (Resolve-Path -LiteralPath $allowFile -ErrorAction SilentlyContinue)
$hits = 0
$checked = 0

foreach ($p in $Path) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        Write-Output "${p}:0: missing-path"
        $hits++
        continue
    }
    $full = (Resolve-Path -LiteralPath $p).Path
    if ($allowFull -and $full -eq $allowFull.Path) { continue }

    $buf = New-Object byte[] 8192
    $fs = [IO.File]::OpenRead($full)
    try { $n = $fs.Read($buf, 0, $buf.Length) } finally { $fs.Dispose() }
    if ($n -gt 0 -and [Array]::IndexOf($buf, [byte]0, 0, $n) -ge 0) { continue }

    $checked++
    $lineNo = 0
    foreach ($line in [IO.File]::ReadLines($full)) {
        $lineNo++
        if ($emailRx.IsMatch($line)) { Write-Output "${p}:${lineNo}: e-mail"; $hits++ }
        foreach ($m in $guidRx.Matches($line)) {
            if (-not $allowed.ContainsKey($m.Value.ToLowerInvariant())) {
                Write-Output "${p}:${lineNo}: guid"; $hits++
            }
        }
        foreach ($d in $deny) {
            if ($line.IndexOf($d, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                Write-Output "${p}:${lineNo}: deny-list"; $hits++
            }
        }
    }
}

if ($hits -gt 0) {
    Write-Output "public-content: $hits hit(s)"
    $Host.SetShouldExit(1); exit 1
}
Write-Output "public-content: clean ($checked files)"

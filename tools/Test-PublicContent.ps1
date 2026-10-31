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
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$Path = @(),
    [string]$DenyListPath = (Join-Path $HOME '.config/green-is-not-proof/deny.txt'),
    [string]$AllowListPath = (Join-Path $PSScriptRoot 'public-content-allow.txt')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$allowFile = $AllowListPath
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
$hits = 0
$checked = 0

foreach ($p in $Path) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        Write-Output "${p}:0: missing-path"
        $hits++
        continue
    }
    $full = (Resolve-Path -LiteralPath $p).Path

    $bytes = [IO.File]::ReadAllBytes($full)
    $n = $bytes.Length
    $enc = $null; $skip = 0
    if ($n -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) { $enc = [Text.UTF32Encoding]::new($false, $true); $skip = 4 }
    elseif ($n -ge 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) { $enc = [Text.UTF32Encoding]::new($true, $true); $skip = 4 }
    elseif ($n -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $enc = [Text.UTF8Encoding]::new($true); $skip = 3 }
    elseif ($n -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $enc = [Text.UnicodeEncoding]::new($false, $true); $skip = 2 }
    elseif ($n -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { $enc = [Text.UnicodeEncoding]::new($true, $true); $skip = 2 }
    elseif ($n -gt 0 -and [Array]::IndexOf($bytes, [byte]0, 0, [Math]::Min($n, 8192)) -ge 0) { continue }
    else { $enc = [Text.UTF8Encoding]::new($false) }

    $checked++
    $lineNo = 0
    $text = $enc.GetString($bytes, $skip, $n - $skip)
    foreach ($line in $text -split '\r?\n') {
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

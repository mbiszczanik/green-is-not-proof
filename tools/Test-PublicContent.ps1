<#
.SYNOPSIS
Fails when tracked files contain e-mail addresses, GUIDs or deny-listed terms.
.DESCRIPTION
Prints file:line: <kind> per hit and exits 1; otherwise prints a clean summary and exits 0.
GUIDs listed in tools/public-content-allow.txt (built-in Azure ids) are allowed. The deny list
(tenant and organisation names, one per line, # comments) is a local untracked file; if it is
missing, only e-mails and GUIDs are checked. A binary file is not scanned; each one prints
'skipped binary: <path>' without failing.
-CommitRange <git range> additionally scans every commit message in the range and every blob added or
modified by its commits, reporting 'commit <sha7>: <kind> (<where>)'. Run it from inside the repository.
.EXAMPLE
./tools/Test-PublicContent.ps1 -Path (git ls-files)
.EXAMPLE
./tools/Test-PublicContent.ps1 -CommitRange origin/main..HEAD
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$Path = @(),
    [string]$CommitRange,
    [string]$DenyListPath = (Join-Path $HOME '.config/green-is-not-proof/deny.txt'),
    [string]$AllowListPath = (Join-Path $PSScriptRoot 'public-content-allow.txt')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ((-not $Path -or $Path.Count -eq 0) -and -not $CommitRange) {
    Write-Output 'public-content: no files to check'
    exit 1
}

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

# Returns the decoded text, or $null for a binary file (a NUL in the first 8 KiB and no BOM).
function ConvertFrom-ScanByteArray([byte[]]$bytes) {
    $n = $bytes.Length
    $enc = $null; $skip = 0
    if ($n -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) { $enc = [Text.UTF32Encoding]::new($false, $true); $skip = 4 }
    elseif ($n -ge 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) { $enc = [Text.UTF32Encoding]::new($true, $true); $skip = 4 }
    elseif ($n -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $enc = [Text.UTF8Encoding]::new($true); $skip = 3 }
    elseif ($n -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $enc = [Text.UnicodeEncoding]::new($false, $true); $skip = 2 }
    elseif ($n -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { $enc = [Text.UnicodeEncoding]::new($true, $true); $skip = 2 }
    elseif ($n -gt 0 -and [Array]::IndexOf($bytes, [byte]0, 0, [Math]::Min($n, 8192)) -ge 0) { return $null }
    else { $enc = [Text.UTF8Encoding]::new($false) }
    $enc.GetString($bytes, $skip, $n - $skip)
}

# Returns one object per hit: Line and Kind.
function Find-Hit([string]$Text) {
    $lineNo = 0
    foreach ($line in $Text -split '?
') {
        $lineNo++
        if ($emailRx.IsMatch($line)) { [pscustomobject]@{ Line = $lineNo; Kind = 'e-mail' } }
        foreach ($m in $guidRx.Matches($line)) {
            if (-not $allowed.ContainsKey($m.Value.ToLowerInvariant())) { [pscustomobject]@{ Line = $lineNo; Kind = 'guid' } }
        }
        foreach ($d in $deny) {
            if ($line.IndexOf($d, [StringComparison]::OrdinalIgnoreCase) -ge 0) { [pscustomobject]@{ Line = $lineNo; Kind = 'deny-list' } }
        }
    }
}

function Invoke-Git([string[]]$GitArgs) {
    $r = & git @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed" }
    $r
}

function Get-GitBlobContent([string]$Spec) {
    $psi = [Diagnostics.ProcessStartInfo]::new('git')
    foreach ($a in 'cat-file', 'blob', $Spec) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $proc = [Diagnostics.Process]::Start($psi)
    $ms = [IO.MemoryStream]::new()
    $proc.StandardOutput.BaseStream.CopyTo($ms)
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) { throw "git cat-file blob $Spec failed" }
    , $ms.ToArray()
}

foreach ($p in $Path) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        Write-Output "${p}:0: missing-path"
        $hits++
        continue
    }
    $full = (Resolve-Path -LiteralPath $p).Path
    $text = ConvertFrom-ScanByteArray ([IO.File]::ReadAllBytes($full))
    if ($null -eq $text) { Write-Output "skipped binary: $p"; continue }
    $checked++
    foreach ($h in Find-Hit $text) { Write-Output "${p}:$($h.Line): $($h.Kind)"; $hits++ }
}

if ($CommitRange) {
    $commits = @(Invoke-Git (@('log', '--format=%H') + @($CommitRange -split '\s+' | Where-Object { $_ })))
    foreach ($sha in $commits) {
        $short = $sha.Substring(0, 7)
        $checked++
        foreach ($h in Find-Hit ((Invoke-Git @('log', '-1', '--format=%B', $sha)) -join "`n")) {
            Write-Output "commit ${short}: $($h.Kind) (message)"; $hits++
        }
        $names = @(Invoke-Git @('diff-tree', '--root', '--no-commit-id', '--name-only', '-r', '--diff-filter=AM', '--no-renames', '-z', $sha) |
                ForEach-Object { $_ -split "`0" } | Where-Object { $_ })
        foreach ($name in $names) {
            $text = ConvertFrom-ScanByteArray (Get-GitBlobContent "${sha}:$name")
            if ($null -eq $text) { Write-Output "skipped binary: $name"; continue }
            foreach ($h in Find-Hit $text) { Write-Output "commit ${short}: $($h.Kind) (${name}:$($h.Line))"; $hits++ }
        }
    }
}

if ($hits -gt 0) {
    Write-Output "public-content: $hits hit(s)"
    exit 1
}
Write-Output "public-content: clean ($checked files)"

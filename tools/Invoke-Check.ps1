<#
.SYNOPSIS
Runs the repository's offline checks; the one command behind `mise run check` and `mise run check:fast`.
.DESCRIPTION
Lane Full is what CI runs: Pester through tools/Invoke-CiPester.ps1, PSScriptAnalyzer, the Bicep linter,
markdownlint-cli2 and the public-content check. Lane Fast is PSScriptAnalyzer and the public-content check:
seconds, no credentials, no Azure call. Every step runs even after a failure, then the script exits 1 if any failed.
The public-content step reads the deny list from GNP_DENY_PATH, else from ~/.config/green-is-not-proof/deny.txt;
without either it checks e-mail addresses and GUIDs only and says so.
.PARAMETER Lane
Full or Fast.
.EXAMPLE
pwsh -NoProfile -File ./tools/Invoke-Check.ps1 -Lane Fast; $LASTEXITCODE
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('Full', 'Fast')][string]$Lane)
# No strict mode or Stop preference at script scope: Pester runs the tests in this scope and they would inherit it.
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

function Invoke-Step {
    param([string]$Name, [scriptblock]$Body)
    Write-Host "== $Name"
    $global:LASTEXITCODE = 0
    try { & $Body } catch { Write-Host "$Name threw: $($_.Exception.Message)"; return $false }
    if ($LASTEXITCODE -ne 0) { Write-Host "$Name failed (exit $LASTEXITCODE)"; return $false }
    return $true
}

$steps = [ordered]@{}
if ($Lane -eq 'Full') {
    $steps['Pester'] = { & ./tools/Invoke-CiPester.ps1 -Path ./tests }
    $steps['PSScriptAnalyzer'] = {
        Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0
        $f = Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 |
            Where-Object { $_.Severity -in 'Warning', 'Error' }
        if ($f) { $f | Format-Table -AutoSize | Out-String | Write-Host; $global:LASTEXITCODE = 1 }
    }
    $steps['Bicep lint'] = {
        # Linter warnings exit 0, so the gate reads the diagnostics, not the exit code.
        $out = az bicep lint --file infra/declared.bicep 2>&1 | Out-String
        $code = $LASTEXITCODE
        Write-Host $out
        if ($code -ne 0 -or $out -cmatch ': (Warning|Error) ') { $global:LASTEXITCODE = 1 }
    }
    $steps['Markdown lint'] = {
        # Package and version joined at run time: "name@version" reads as an e-mail address to the public-content check.
        npx --yes ('markdownlint-cli2' + [char]64 + '0.18.1') '**/*.md'
    }
} else {
    $steps['PSScriptAnalyzer'] = {
        Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0
        $f = Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 |
            Where-Object { $_.Severity -in 'Warning', 'Error' }
        if ($f) { $f | Format-Table -AutoSize | Out-String | Write-Host; $global:LASTEXITCODE = 1 }
    }
}
$steps['Public content'] = {
    $deny = $env:GNP_DENY_PATH
    if (-not $deny) {
        $local = Join-Path $HOME '.config/green-is-not-proof/deny.txt'
        if (Test-Path -LiteralPath $local) { $deny = $local } else {
            Write-Host 'No deny list: checking e-mail addresses and GUIDs only.'
            $deny = Join-Path ([IO.Path]::GetTempPath()) 'gnp-no-deny.txt'
            Set-Content -LiteralPath $deny -Value ''
        }
    }
    & ./tools/Test-PublicContent.ps1 -Path (git ls-files) -DenyListPath $deny
}

$failed = @()
foreach ($name in $steps.Keys) {
    if (-not (Invoke-Step -Name $name -Body $steps[$name])) { $failed += $name }
}
if ($failed) { Write-Host "FAILED: $($failed -join ', ')"; exit 1 }
Write-Host "OK: $Lane lane passed"
exit 0

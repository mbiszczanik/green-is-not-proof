<#
.SYNOPSIS
Demo 0, the green: lists resources carrying the project tags and reports OK.
.DESCRIPTION
Looks only at tags, never at the code's manifest. The rogue VM carries the tags, so the audit passes.
RunId comes from -RunId or out/run.json.
.EXAMPLE
./demos/0-tag-is-not-ownership/Invoke-TagAudit.ps1
#>
[CmdletBinding()]
param(
    [string]$RunId,
    [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../../lib/Mask.ps1
. $PSScriptRoot/../../lib/Ownership.ps1

function Invoke-TagAudit {
    <#
    .SYNOPSIS
    Prints the tagged resources and the OK line; returns 0, or 1 on any failure.
    .EXAMPLE
    $code = Invoke-TagAudit -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([string]$RunId, [Parameter(Mandatory)][string]$OutDir)
    $sub = ''
    try {
        $ctx = Get-AzContext
        if (-not $ctx) { Write-Host 'Run Connect-AzAccount first'; return 1 }
        $sub = $ctx.Subscription.Id
        $RunId = Resolve-AuditRunId -RunId $RunId -OutDir $OutDir
        $found = @(Get-AzResource -TagName 'project' -TagValue 'green-is-not-proof' |
                Where-Object { $_.Tags -and $_.Tags['runId'] -eq $RunId })
        if ($found.Count -eq 0) { throw 'Empty inventory' }
        $table = $found | Select-Object Name, ResourceType | Write-DemoOutput -SubscriptionId $sub
        Write-Host $table
        Write-Host ''
        Write-Host "All $($found.Count) resources carry project tags: OK"
        return 0
    }
    catch {
        Write-Host (ConvertTo-MaskedText -Text "Tag audit failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../../out' }
    $code = Invoke-TagAudit -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { $Host.SetShouldExit(1); exit 1 }
}

<#
.SYNOPSIS
Child process of demo 7: runs Assert-PSRule with the Azure rules on one file and exits with its status.
.DESCRIPTION
Run as `pwsh -NoProfile -File` so the exit code is the process's own. -ExpandBicep Off leaves the Bicep file
unexpanded, so PSRule sees the file as an object and no Azure rule targets it. Exits 1 when PSRule.Rules.Azure
is not installed, so a missing module is never a pass.
.EXAMPLE
pwsh -NoProfile -File ./Invoke-PSRuleChild.ps1 -Path ./Storage.bicep -ExpandBicep On
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ValidateSet('On', 'Off')][string]$ExpandBicep
)
if (-not (Get-Module -ListAvailable PSRule.Rules.Azure)) {
    Write-Host 'PSRule.Rules.Azure is not installed: the rules cannot run, so no gate result exists.'
    exit 1
}
Import-Module PSRule.Rules.Azure
# 30 s: the 5 s default times out on a busy laptop and PSRule then evaluates no rule.
$option = New-PSRuleOption -Option @{ 'Configuration.AZURE_BICEP_FILE_EXPANSION' = ($ExpandBicep -eq 'On'); 'Configuration.AZURE_BICEP_FILE_EXPANSION_TIMEOUT' = 30; 'Output.Style' = 'Plain' }
try {
    Assert-PSRule -Module PSRule.Rules.Azure -InputPath $Path -Format File -Option $option -ErrorAction Stop
}
catch {
    Write-Host $_.Exception.Message
    exit 1
}
exit 0

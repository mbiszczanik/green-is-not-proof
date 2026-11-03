# Never executed; parsed only.
<#
.SYNOPSIS
Example deployment script with every mutation inside the non-dry branch.
.EXAMPLE
./Deploy-Example.Fixed.ps1 -DryRun
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Parsed-only demo input.')]
param(
    [switch]$DryRun,
    [string]$ResourceGroupName = 'rg-demo',
    [string]$TemplateFile = './main.bicep'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($DryRun) {
    Write-Output 'Dry run: skipping deployment'
}
else {
    Register-AzResourceProvider -ProviderNamespace Microsoft.Insights
    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile
}

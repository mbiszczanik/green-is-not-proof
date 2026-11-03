# Never executed; parsed only.
<#
.SYNOPSIS
Example deployment script with a -DryRun switch.
.EXAMPLE
./Deploy-Example.ps1 -DryRun
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Parsed-only demo input.')]
param(
    [switch]$DryRun,
    [string]$ResourceGroupName = 'rg-demo',
    [string]$TemplateFile = './main.bicep'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Register-AzResourceProvider -ProviderNamespace Microsoft.Insights

if ($DryRun) {
    Write-Output 'Dry run: skipping deployment'
}
else {
    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile
}

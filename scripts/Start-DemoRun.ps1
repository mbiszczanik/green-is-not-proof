<#
.SYNOPSIS
Builds one demo run's declared Azure resources after the cost guard approves it, and writes out/run.json.
.DESCRIPTION
Order: Az context check, cost guard (2 hours, limit 2 EUR, every item of the run including the rogue VM that
scripts/New-RogueResource.ps1 adds later), resource group, then one deployment of infra/declared.bicep
(Log Analytics workspace, storage account with a blob diagnostic setting, VNet with subnet snet-app).
That deployment's record is demo 0's expected inventory. run.json holds raw ids (out/ is gitignored);
console output masks the subscription id. The current subscription must match GNP_SUBSCRIPTION_ID or
~/.config/green-is-not-proof/subscription.txt, and a leftover out/run.json from an untorn run stops the start.
Needs the Bicep CLI on PATH.
.EXAMPLE
./scripts/Start-DemoRun.ps1 -Location swedencentral
#>
[CmdletBinding()]
param(
    [string]$Location = 'swedencentral',
    [string]$RunId,
    [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../lib/RunContext.ps1
. $PSScriptRoot/../lib/Mask.ps1
. $PSScriptRoot/../lib/CostGuard.ps1

function Invoke-StartDemoRun {
    <#
    .SYNOPSIS
    Runs the setup and returns 0 on success or 1 on any failure (nothing is created when the guard fails).
    .EXAMPLE
    $code = Invoke-StartDemoRun -RunId (New-DemoRunId) -Location swedencentral -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string]$Location = 'swedencentral',
        [string]$RunId,
        [Parameter(Mandatory)][string]$OutDir
    )
    $sub = ''
    $run = $null
    try {
        $ctx = Get-AzContext
        if (-not $ctx) { Write-Host 'Run Connect-AzAccount first'; return 1 }
        $sub = $ctx.Subscription.Id
        Assert-DemoSubscription -Expected (Get-DemoExpectedSubscriptionId) -Current $sub
        if (-not $RunId) { $RunId = New-DemoRunId }
        if ($RunId -notmatch '^\d{12}$') { throw "RunId must be 12 digits (yyyyMMddHHmm), got '$RunId'" }
        $runFile = Join-Path $OutDir 'run.json'
        if (Test-Path -LiteralPath $runFile) {
            $prev = (Get-Content -LiteralPath $runFile -Raw | ConvertFrom-Json).RunId
            Write-Host "A previous run ($prev) was not torn down. Run scripts/Stop-DemoRun.ps1 first."
            return 1
        }

        $items = (Import-PowerShellDataFile $PSScriptRoot/../config/demo-resources.psd1).Items
        $estimate = Get-DemoRunCostEstimate -Items $items -Region $Location -Hours 2
        Assert-DemoRunBudget -Estimate $estimate
        Write-Host ("Cost guard passed: {0} EUR for 2 hours" -f $estimate.TotalEur)

        $tag = Get-DemoTag -RunId $RunId
        $rg = Get-DemoResourceGroupName -RunId $RunId
        $deploymentName = Get-DemoDeploymentName -RunId $RunId

        if (Test-DemoResourceGroup -Name $rg) { throw "Resource group $rg already exists; refusing to reuse it" }
        $null = New-Item -ItemType Directory -Force -Path $OutDir
        $null = New-AzResourceGroup -Name $rg -Location $Location -Tag $tag
        # Written right after the group exists so a later failure still leaves a record for teardown.
        $run = [ordered]@{ RunId = $RunId; SubscriptionId = $sub; ResourceGroup = $rg; Location = $Location; DeploymentName = $deploymentName }
        $run | ConvertTo-Json | Set-Content -Path $runFile -Encoding utf8
        $params = @{ runId = $RunId; location = $Location; tags = $tag }
        $dep = New-AzResourceGroupDeployment -ResourceGroupName $rg -Name $deploymentName -TemplateFile $PSScriptRoot/../infra/declared.bicep -TemplateParameterObject $params
        if (-not $dep -or $dep.ProvisioningState -ne 'Succeeded') {
            $state = if ($dep) { $dep.ProvisioningState } else { 'no result' }
            throw "Deployment $deploymentName ended $state"
        }
        $run.WorkspaceId = [string]$dep.Outputs['workspaceId'].Value
        $run.StorageAccountName = [string]$dep.Outputs['storageAccountName'].Value
        $run.VnetName = [string]$dep.Outputs['vnetName'].Value
        $run | ConvertTo-Json | Set-Content -Path $runFile -Encoding utf8
        Write-Host (([pscustomobject]$run | Write-DemoOutput -SubscriptionId $sub))
        Write-Host 'Next, outside the declared deployment: ./scripts/New-RogueResource.ps1'
        return 0
    }
    catch {
        $msg = ConvertTo-SafeText -Text "Start-DemoRun failed: $($_.Exception.Message)" -SubscriptionId $sub
        Write-Host $msg
        if ($run) { Write-Host (ConvertTo-SafeText -Text "Partial run: $($run.ResourceGroup) exists. Run scripts/Stop-DemoRun.ps1 -RunId $RunId to tear it down." -SubscriptionId $sub) }
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../out' }
    $code = Invoke-StartDemoRun -Location $Location -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}

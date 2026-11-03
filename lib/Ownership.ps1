function Find-UnownedResource {
    <#
    .SYNOPSIS
    Returns inventory items whose resource id the deployment record does not list.
    .DESCRIPTION
    Ids match case-insensitively. An inventory item's id is read from Id, else ResourceId.
    .EXAMPLE
    Find-UnownedResource -Inventory (Get-AzResource -ResourceGroupName $rg) -ExpectedId $ids
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Inventory,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ExpectedId
    )
    if (-not $Inventory -or $Inventory.Count -eq 0) { throw 'Empty inventory' }
    $expected = [System.Collections.Generic.HashSet[string]]::new([string[]]$ExpectedId, [StringComparer]::OrdinalIgnoreCase)
    @($Inventory | ForEach-Object {
            $id = if ($_.PSObject.Properties['Id'] -and $_.Id) { [string]$_.Id } else { [string]$_.ResourceId }
            if (-not $expected.Contains($id)) { [pscustomobject]@{ Name = $_.Name; ResourceType = $_.ResourceType; Id = $id } }
        }) | Sort-Object -Property Id -Unique
}

function Get-DeclaredResourceId {
    <#
    .SYNOPSIS
    Returns the resource ids a succeeded deployment created, read from its deployment operations.
    .DESCRIPTION
    Throws when the deployment record is missing, not Succeeded, or lists no resources, so a missing record
    never reads as "nothing declared" or "everything declared".
    .EXAMPLE
    Get-DeclaredResourceId -ResourceGroupName rg-gnp-202611181805 -DeploymentName declared-202611181805
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$DeploymentName
    )
    try { $dep = Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $DeploymentName -ErrorAction Stop }
    catch { throw "Deployment record $DeploymentName not readable in ${ResourceGroupName}: $($_.Exception.Message)" }
    if (-not $dep) { throw "Deployment record $DeploymentName not found in $ResourceGroupName" }
    if ($dep.ProvisioningState -ne 'Succeeded') { throw "Deployment record $DeploymentName is $($dep.ProvisioningState), not Succeeded" }
    $ids = @(Get-AzResourceGroupDeploymentOperation -ResourceGroupName $ResourceGroupName -DeploymentName $DeploymentName -ErrorAction Stop |
            ForEach-Object { [string]$_.TargetResource } | Where-Object { $_ } | Sort-Object -Unique)
    if ($ids.Count -eq 0) { throw "Deployment record $DeploymentName lists no resources" }
    $ids
}

function Resolve-AuditRunId {
    <#
    .SYNOPSIS
    Returns the given run id, else the one in run.json under OutDir; throws when neither exists.
    .EXAMPLE
    Resolve-AuditRunId -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$RunId, [Parameter(Mandatory)][string]$OutDir)
    if ($RunId) { return $RunId }
    $file = Join-Path $OutDir 'run.json'
    if (-not (Test-Path $file)) { throw "No -RunId given and $file not found" }
    $id = (Get-Content $file -Raw | ConvertFrom-Json).RunId
    if (-not $id) { throw "$file has no RunId" }
    [string]$id
}

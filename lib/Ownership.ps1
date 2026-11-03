function Find-UnownedResource {
    <#
    .SYNOPSIS
    Returns inventory items whose name the code does not declare, plus the children of a flagged VM.
    .DESCRIPTION
    Names match case-insensitively. A child of a flagged VM has a name starting with the VM name and
    '-' or '_' (NIC, Azure-named OS disk), or a ManagedBy property ending with the VM id.
    .EXAMPLE
    Find-UnownedResource -Inventory (Get-AzResource -ResourceGroupName $rg) -ExpectedName $names
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Inventory,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ExpectedName
    )
    if (-not $Inventory -or $Inventory.Count -eq 0) { throw 'Empty inventory' }
    $expected = [System.Collections.Generic.HashSet[string]]::new([string[]]$ExpectedName, [StringComparer]::OrdinalIgnoreCase)
    $flagged = @($Inventory | Where-Object { -not $expected.Contains([string]$_.Name) })
    $vms = @($flagged | Where-Object { $_.ResourceType -eq 'Microsoft.Compute/virtualMachines' })
    $children = foreach ($item in $Inventory) {
        foreach ($vm in $vms) {
            $managedBy = if ($item.PSObject.Properties['ManagedBy']) { [string]$item.ManagedBy } else { '' }
            $prefix = [string]$vm.Name
            if ($item.Name.StartsWith("$prefix-", [StringComparison]::OrdinalIgnoreCase) -or
                $item.Name.StartsWith("${prefix}_", [StringComparison]::OrdinalIgnoreCase) -or
                ($managedBy -and $managedBy.EndsWith([string]$vm.Id, [StringComparison]::OrdinalIgnoreCase))) { $item; break }
        }
    }
    @($flagged) + @($children) | Sort-Object -Property Id -Unique |
        Select-Object -Property Name, ResourceType, Id
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

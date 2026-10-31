BeforeAll {
    . $PSScriptRoot/../lib/Ownership.ps1
    function script:Res($Name, $Type = 'Microsoft.Network/virtualNetworks') {
        [pscustomobject]@{ Name = $Name; ResourceType = $Type; Id = "/subscriptions/x/resourceGroups/rg/providers/$Type/$Name" }
    }
}

Describe 'Find-UnownedResource' {
    It 'flags a tagged resource absent from the manifest' {
        $inv = @((Res 'vnet-gnp'), (Res 'vm-traffic' 'Microsoft.Compute/virtualMachines'))
        $r = @(Find-UnownedResource -Inventory $inv -ExpectedName @('vnet-gnp'))
        $r.Name | Should -Be 'vm-traffic'
        $r[0].ResourceType | Should -Be 'Microsoft.Compute/virtualMachines'
        $r[0].Id | Should -Match 'vm-traffic$'
    }

    It 'owned resources are not flagged (case-insensitive names)' {
        $inv = @((Res 'VNET-GNP'), (Res 'StgNP202611181805' 'Microsoft.Storage/storageAccounts'))
        @(Find-UnownedResource -Inventory $inv -ExpectedName @('vnet-gnp', 'stgnp202611181805')).Count | Should -Be 0
    }

    It 'child resources of a flagged VM are flagged' {
        $inv = @(
            (Res 'vnet-gnp'),
            (Res 'vm-traffic' 'Microsoft.Compute/virtualMachines'),
            (Res 'vm-traffic-nic' 'Microsoft.Network/networkInterfaces'),
            (Res 'vm-traffic_OsDisk_1_abc123' 'Microsoft.Compute/disks'),
            (Res 'vm-trafficker' 'Microsoft.Network/networkInterfaces')
        )
        $names = (Find-UnownedResource -Inventory $inv -ExpectedName @('vnet-gnp', 'vm-traffic-nic', 'vm-trafficker')).Name
        $names | Should -Contain 'vm-traffic'
        $names | Should -Contain 'vm-traffic-nic'
        $names | Should -Contain 'vm-traffic_OsDisk_1_abc123'
        $names | Should -Not -Contain 'vm-trafficker'
        $names | Should -Not -Contain 'vnet-gnp'
    }

    It 'flags a disk whose ManagedBy ends with the flagged VM id' {
        $vm = Res 'vm-traffic' 'Microsoft.Compute/virtualMachines'
        $disk = Res 'datadisk1' 'Microsoft.Compute/disks'
        $disk | Add-Member -NotePropertyName ManagedBy -NotePropertyValue $vm.Id
        (Find-UnownedResource -Inventory @($vm, $disk) -ExpectedName @('datadisk1')).Name | Should -Contain 'datadisk1'
    }

    It 'empty inventory is an error' {
        { Find-UnownedResource -Inventory @() -ExpectedName @('vnet-gnp') } | Should -Throw 'Empty inventory'
    }
}

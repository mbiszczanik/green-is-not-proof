# Priced items of one demo run. Unit: Hour (x hours), Month (/730 x hours), Run (once). Log Analytics uses the paid tier (ignores the free 5 GB): a conservative estimate.
@{
    Items = @(
        @{ Name = 'vm-b1s'; ServiceName = 'Virtual Machines'; ArmSkuName = 'Standard_B1s'; MeterName = 'B1s'; ProductName = 'Virtual Machines BS Series'; Quantity = 1; Unit = 'Hour' }
        @{ Name = 'os-disk-e4'; ServiceName = 'Storage'; ArmSkuName = ''; MeterName = 'E4 LRS Disk'; ProductName = 'Standard SSD Managed Disks'; Quantity = 1; Unit = 'Month' }
        @{ Name = 'storage-lrs-hot'; ServiceName = 'Storage'; ArmSkuName = ''; MeterName = 'Hot LRS Data Stored'; ProductName = 'General Block Blob v2'; Quantity = 1; Unit = 'Month' }
        @{ Name = 'log-analytics-gb'; ServiceName = 'Log Analytics'; ArmSkuName = ''; MeterName = 'Analytics Logs Data Ingestion'; ProductName = 'Log Analytics'; TierMinimumUnits = 5; Quantity = 0.1; Unit = 'Run' }
    )
}

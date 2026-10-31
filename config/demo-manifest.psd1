# Resources Start-DemoRun.ps1 creates from code. {runId} is replaced with the run id.
# vm-traffic, its NIC and its OS disk are absent on purpose: the rogue VM is the drift the demo reveals.
@{
    Names = @(
        'rg-gnp-{runId}'
        'log-gnp-{runId}'
        'stgnp{runId}'
        'vnet-gnp'
        'diag-to-log'
    )
}

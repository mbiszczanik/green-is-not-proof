BeforeAll {
    . $PSScriptRoot/../lib/RunContext.ps1
}

Describe 'RunContext' {
    It 'run id from fixed date' {
        New-DemoRunId -Now ([datetime]'2026-11-18 18:05') | Should -Be '202611181805'
    }
    It 'resource group name' {
        Get-DemoResourceGroupName -RunId '202611181805' | Should -Be 'rg-gnp-202611181805'
    }
    It 'tags carry project and runId' {
        $t = Get-DemoTag -RunId '202611181805'
        $t.project | Should -Be 'green-is-not-proof'
        $t.runId | Should -Be '202611181805'
    }
}

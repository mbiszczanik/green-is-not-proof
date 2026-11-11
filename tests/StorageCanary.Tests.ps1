BeforeDiscovery {
    $script:HasRules = [bool](Get-Module -ListAvailable PSRule.Rules.Azure)
}

BeforeAll {
    $script:Dir = Join-Path $PSScriptRoot '../demos/7-unprocessed-object-passes'
    $script:Rules = 'Azure.Storage.MinTLS', 'Azure.Storage.BlobPublicAccess'
    $script:Type = 'Microsoft.Storage/storageAccounts'
    function script:New-Record($Rule, $Target, $Outcome, $Type = 'Microsoft.Storage/storageAccounts') {
        [pscustomobject]@{ RuleName = $Rule; TargetName = $Target; TargetType = $Type; Outcome = $Outcome }
    }
    function script:New-Expected($Target, $Outcome) {
        $script:Rules | ForEach-Object { @{ Rule = $_; Target = $Target; Type = $script:Type; Outcome = $Outcome } }
    }

    # One message per expected record that is missing or has another outcome; Error records always fail, Fail records with -NoFail.
    function script:Get-RuleEvidenceFailure {
        param([object[]]$Record = @(), [hashtable[]]$Expected, [switch]$NoFail)
        $out = @()
        foreach ($e in $Expected) {
            $hit = @($Record | Where-Object { $_.RuleName -eq $e.Rule -and $_.TargetName -eq $e.Target -and $_.TargetType -eq $e.Type })
            if ($hit.Count -eq 0) { $out += "missing record for rule $($e.Rule) on target '$($e.Target)' of type $($e.Type)"; continue }
            foreach ($h in $hit) { if ($h.Outcome -ne $e.Outcome) { $out += "rule $($e.Rule) outcome is $($h.Outcome), expected $($e.Outcome)" } }
        }
        $err = @($Record | Where-Object { $_.Outcome -eq 'Error' })
        if ($err.Count -gt 0) { $out += "$($err.Count) record(s) with outcome Error" }
        if ($NoFail) {
            $bad = @($Record | Where-Object { $_.Outcome -eq 'Fail' })
            if ($bad.Count -gt 0) { $out += "$($bad.Count) record(s) with outcome Fail" }
        }
        $out
    }

    # Runs the evaluator; a throw or a Bicep compilation timeout is an infrastructure failure, never a statement about the account.
    function script:Invoke-RuleEvaluation {
        param(
            [Parameter(Mandatory)][string]$Path,
            [bool]$ExpandBicep = $true,
            [scriptblock]$Evaluator = {
                param($Path, $ExpandBicep)
                Import-Module PSRule.Rules.Azure
                $opt = New-PSRuleOption -Option @{ 'Configuration.AZURE_BICEP_FILE_EXPANSION' = $ExpandBicep; 'Output.Style' = 'Plain' }
                $rec = Invoke-PSRule -Module PSRule.Rules.Azure -InputPath $Path -Format File -Option $opt -WarningVariable w -ErrorVariable e -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                [pscustomobject]@{
                    Record     = @($rec)
                    Diagnostic = @(@($w) | Where-Object { $_ } | ForEach-Object { "$_" })
                    Error      = @(@($e) | Where-Object { $_ } | ForEach-Object { "$_" })
                }
            }
        )
        try { $r = & $Evaluator $Path $ExpandBicep }
        catch { return [pscustomobject]@{ Records = @(); Infrastructure = "infrastructure failure: the evaluation threw: $($_.Exception.Message)" } }
        # PSRule 2.9.0 emits this one error in PSRule.psm1 on a run that returns all 21 records (seen outside Pester too); any other error fails.
        $errs = @($r.Error | Where-Object { $_ -and $_ -notmatch "^Cannot find a variable with the name 'PSModuleAutoLoadingPreference'" })
        if ($errs.Count -gt 0) {
            return [pscustomobject]@{ Records = @(); Infrastructure = "infrastructure failure: the evaluation reported $($errs.Count) error(s): $($errs -join ' | ')" }
        }
        $diag = (@($r.Diagnostic) -join ' | ')
        if ($diag -match '(?i)compilation.*(timeout|completed within)') {
            return [pscustomobject]@{ Records = @(); Infrastructure = "infrastructure failure: Bicep compilation did not complete (timeout): $diag" }
        }
        [pscustomobject]@{ Records = @($r.Record); Infrastructure = $null }
    }

    function script:Get-EvaluationFailure {
        param($Evaluation, [hashtable[]]$Expected, [switch]$NoFail)
        if ($Evaluation.Infrastructure) { return @($Evaluation.Infrastructure) }
        @(Get-RuleEvidenceFailure -Record $Evaluation.Records -Expected $Expected -NoFail:$NoFail)
    }
}

Describe 'Get-RuleEvidenceFailure' {
    It 'returns nothing when every expected record is present and nothing failed unexpectedly' {
        $rec = @((New-Record 'Azure.Storage.MinTLS' 'sa1' 'Fail'), (New-Record 'Azure.Storage.BlobPublicAccess' 'sa1' 'Fail'))
        @(Get-RuleEvidenceFailure -Record $rec -Expected (New-Expected 'sa1' 'Fail')) | Should -BeNullOrEmpty
    }

    It 'names a missing record' {
        $rec = @(New-Record 'Azure.Storage.MinTLS' 'sa1' 'Fail')
        $f = @(Get-RuleEvidenceFailure -Record $rec -Expected (New-Expected 'sa1' 'Fail'))
        $f.Count | Should -Be 1
        $f[0] | Should -Match 'missing record for rule Azure.Storage.BlobPublicAccess'
    }

    It 'names a wrong target name' {
        $rec = @((New-Record 'Azure.Storage.MinTLS' 'other' 'Fail'), (New-Record 'Azure.Storage.BlobPublicAccess' 'sa1' 'Fail'))
        $f = @(Get-RuleEvidenceFailure -Record $rec -Expected (New-Expected 'sa1' 'Fail'))
        $f.Count | Should -Be 1
        $f[0] | Should -Match "missing record for rule Azure.Storage.MinTLS on target 'sa1'"
    }

    It 'names a wrong target type' {
        $rec = @((New-Record 'Azure.Storage.MinTLS' 'sa1' 'Fail' 'Microsoft.Network/virtualNetworks'), (New-Record 'Azure.Storage.BlobPublicAccess' 'sa1' 'Fail'))
        $f = @(Get-RuleEvidenceFailure -Record $rec -Expected (New-Expected 'sa1' 'Fail'))
        $f.Count | Should -Be 1
        $f[0] | Should -Match 'Azure.Storage.MinTLS'
    }

    It 'names a wrong outcome' {
        $rec = @((New-Record 'Azure.Storage.MinTLS' 'sa1' 'Pass'), (New-Record 'Azure.Storage.BlobPublicAccess' 'sa1' 'Fail'))
        $f = @(Get-RuleEvidenceFailure -Record $rec -Expected (New-Expected 'sa1' 'Fail'))
        $f.Count | Should -Be 1
        $f[0] | Should -Match 'rule Azure.Storage.MinTLS outcome is Pass, expected Fail'
    }

    It 'fails on an Error record even when the expected records are right' {
        $rec = @((New-Record 'Azure.Storage.MinTLS' 'sa1' 'Fail'), (New-Record 'Azure.Storage.BlobPublicAccess' 'sa1' 'Fail'), (New-Record 'Azure.Storage.Other' 'sa1' 'Error'))
        $f = @(Get-RuleEvidenceFailure -Record $rec -Expected (New-Expected 'sa1' 'Fail'))
        $f.Count | Should -Be 1
        $f[0] | Should -Match '1 record\(s\) with outcome Error'
    }

    It 'fails every expected record on an empty result' {
        $f = @(Get-RuleEvidenceFailure -Record @() -Expected (New-Expected 'sa1' 'Fail'))
        $f.Count | Should -Be 2
    }

    It 'with -NoFail fails on any Fail record' {
        $rec = @((New-Record 'Azure.Storage.MinTLS' 'sa1' 'Pass'), (New-Record 'Azure.Storage.BlobPublicAccess' 'sa1' 'Pass'), (New-Record 'Azure.Storage.Firewall' 'sa1' 'Fail'))
        $f = @(Get-RuleEvidenceFailure -Record $rec -Expected (New-Expected 'sa1' 'Pass') -NoFail)
        $f.Count | Should -Be 1
        $f[0] | Should -Match '1 record\(s\) with outcome Fail'
    }
}

Describe 'Invoke-RuleEvaluation' {
    It 'reports a thrown evaluator as an infrastructure failure, not as an assertion about the account' {
        $r = Invoke-RuleEvaluation -Path 'x.bicep' -Evaluator { throw 'boom' }
        $r.Infrastructure | Should -Match 'infrastructure'
        $r.Infrastructure | Should -Match 'boom'
        @($r.Records).Count | Should -Be 0
    }

    It 'reports a Bicep compilation timeout as an infrastructure failure' {
        $r = Invoke-RuleEvaluation -Path 'x.bicep' -Evaluator { [pscustomobject]@{ Record = @(); Diagnostic = @("Bicep compilation hasn't completed within the timeout window") } }
        $r.Infrastructure | Should -Match 'infrastructure'
        $r.Infrastructure | Should -Match 'timeout'
    }

    It 'reports a non-timeout evaluation error with no records as an infrastructure failure, not a missing record' {
        $r = Invoke-RuleEvaluation -Path 'x.bicep' -Evaluator { [pscustomobject]@{ Record = @(); Diagnostic = @(); Error = @('Unable to expand the Bicep file') } }
        $r.Infrastructure | Should -Match 'infrastructure'
        $r.Infrastructure | Should -Match 'Unable to expand'
        $f = @(Get-EvaluationFailure -Evaluation $r -Expected (New-Expected 'sa1' 'Fail'))
        $f.Count | Should -Be 1
        $f[0] | Should -Not -Match 'missing record'
    }

    It 'reports an evaluation error as an infrastructure failure even when the expected records came back' {
        $good = @((New-Record 'Azure.Storage.MinTLS' 'sa1' 'Fail'), (New-Record 'Azure.Storage.BlobPublicAccess' 'sa1' 'Fail'))
        $r = Invoke-RuleEvaluation -Path 'x.bicep' -Evaluator { [pscustomobject]@{ Record = $good; Diagnostic = @(); Error = @('Unable to expand the Bicep file') } }.GetNewClosure()
        $r.Infrastructure | Should -Match 'infrastructure'
        @(Get-EvaluationFailure -Evaluation $r -Expected (New-Expected 'sa1' 'Fail')) | Should -Not -BeNullOrEmpty
    }

    It 'ignores only the known benign PSRule 2.9.0 error and still fails on another error next to it' {
        $benign = "Cannot find a variable with the name 'PSModuleAutoLoadingPreference'."
        $r = Invoke-RuleEvaluation -Path 'x.bicep' -Evaluator { [pscustomobject]@{ Record = @(); Diagnostic = @(); Error = @("Cannot find a variable with the name 'PSModuleAutoLoadingPreference'.") } }
        $r.Infrastructure | Should -BeNullOrEmpty -Because $benign
        $r2 = Invoke-RuleEvaluation -Path 'x.bicep' -Evaluator { [pscustomobject]@{ Record = @(); Diagnostic = @(); Error = @("Cannot find a variable with the name 'PSModuleAutoLoadingPreference'.", 'Unable to expand the Bicep file') } }
        $r2.Infrastructure | Should -Match 'Unable to expand'
        $r2.Infrastructure | Should -Match '1 error'
    }

    It 'keeps a warning that is not a timeout from being an infrastructure failure' {
        $r = Invoke-RuleEvaluation -Path 'x.bicep' -Evaluator { [pscustomobject]@{ Record = @(); Diagnostic = @("Target object 'x.bicep' has not been processed because no matching rules were found."); Error = @() } }
        $r.Infrastructure | Should -BeNullOrEmpty
    }

    It 'treats an evaluation with no records and no diagnostic as a missing-record case, not an infrastructure failure' {
        $r = Invoke-RuleEvaluation -Path 'x.bicep' -Evaluator { [pscustomobject]@{ Record = @(); Diagnostic = @() } }
        $r.Infrastructure | Should -BeNullOrEmpty
        $f = @(Get-EvaluationFailure -Evaluation $r -Expected (New-Expected 'sa1' 'Fail'))
        $f[0] | Should -Match 'missing record'
        $f[0] | Should -Not -Match 'infrastructure'
    }

    It 'reports the infrastructure failure instead of any assertion when the evaluation did not complete' {
        $r = Invoke-RuleEvaluation -Path 'x.bicep' -Evaluator { throw 'boom' }
        $f = @(Get-EvaluationFailure -Evaluation $r -Expected (New-Expected 'sa1' 'Fail'))
        $f.Count | Should -Be 1
        $f[0] | Should -Match 'infrastructure'
    }
}

Describe 'The storage account canary with the real rules' {
    BeforeAll {
        if ($script:HasRules) { $null = Invoke-RuleEvaluation -Path (Join-Path $script:Dir 'Storage.Fixed.bicep') -ExpandBicep $true }
    }

    It 'the insecure account fails the TLS and the public blob access rules, and nothing errors' -Skip:(-not $script:HasRules) {
        $e = Invoke-RuleEvaluation -Path (Join-Path $script:Dir 'Storage.bicep') -ExpandBicep $true
        @(Get-EvaluationFailure -Evaluation $e -Expected (New-Expected 'stdemoinsecure01' 'Fail')) | Should -BeNullOrEmpty
    }

    It 'the corrected account passes the same two rules and nothing else fails' -Skip:(-not $script:HasRules) {
        $e = Invoke-RuleEvaluation -Path (Join-Path $script:Dir 'Storage.Fixed.bicep') -ExpandBicep $true
        @(Get-EvaluationFailure -Evaluation $e -Expected (New-Expected 'stdemosecure01' 'Pass') -NoFail) | Should -BeNullOrEmpty
    }

    It 'with Bicep expansion off no record names the account, and the missing-record message says so' -Skip:(-not $script:HasRules) {
        $e = Invoke-RuleEvaluation -Path (Join-Path $script:Dir 'Storage.bicep') -ExpandBicep $false
        $e.Infrastructure | Should -BeNullOrEmpty
        $f = @(Get-EvaluationFailure -Evaluation $e -Expected (New-Expected 'stdemoinsecure01' 'Fail'))
        $f.Count | Should -Be 2
        $f[0] | Should -Match 'missing record'
    }
}

function Test-DryRunCondition {
    # 'Dry' / 'NotDry' only for the exact forms; anything else is 'Unknown' (never counts as a guard).
    param([System.Management.Automation.Language.Ast]$Condition)
    $names = @('DryRun', 'WhatIfPreference')
    $unwrap = {
        param($ast)
        while ($true) {
            if ($ast -is [System.Management.Automation.Language.PipelineAst] -and $ast.PipelineElements.Count -eq 1) { $ast = $ast.PipelineElements[0] }
            elseif ($ast -is [System.Management.Automation.Language.CommandExpressionAst]) { $ast = $ast.Expression }
            elseif ($ast -is [System.Management.Automation.Language.ParenExpressionAst]) { $ast = $ast.Pipeline }
            else { return $ast }
        }
    }
    $isVar = { param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.VariablePath.UserPath -in $names }
    $expr = & $unwrap $Condition
    if (& $isVar $expr) { return 'Dry' }
    if ($expr -is [System.Management.Automation.Language.UnaryExpressionAst] -and $expr.TokenKind -in @('Not', 'Exclaim')) {
        if (& $isVar (& $unwrap $expr.Child)) { return 'NotDry' }
    }
    'Unknown'
}

function Test-CallGuarded {
    param([System.Management.Automation.Language.CommandAst]$Call)
    $offset = $Call.Extent.StartOffset
    for ($node = $Call.Parent; $node; $node = $node.Parent) {
        # a) call sits in the branch that runs when not dry-run
        if ($node -is [System.Management.Automation.Language.IfStatementAst]) {
            $earlierDry = $false
            $unknownSeen = $false
            foreach ($clause in $node.Clauses) {
                $kind = Test-DryRunCondition -Condition $clause.Item1
                $inBody = $offset -ge $clause.Item2.Extent.StartOffset -and $offset -lt $clause.Item2.Extent.EndOffset
                if ($inBody -and ($kind -eq 'NotDry' -or ($earlierDry -and -not $unknownSeen))) { return $true }
                if ($kind -eq 'Dry') { $earlierDry = $true }
                if ($kind -eq 'Unknown') { $unknownSeen = $true }
            }
            $else = $node.ElseClause
            if ($else -and $earlierDry -and -not $unknownSeen -and $offset -ge $else.Extent.StartOffset -and $offset -lt $else.Extent.EndOffset) { return $true }
        }
        # b) an earlier bare `if ($DryRun) { ...; return|exit|break }` in this or an enclosing block
        if ($node -is [System.Management.Automation.Language.StatementBlockAst] -or $node -is [System.Management.Automation.Language.NamedBlockAst]) {
            foreach ($stmt in $node.Statements) {
                # a statement that contains the call (the dry branch itself) is never its own early exit
                if ($stmt.Extent.StartOffset -ge $offset -or $stmt.Extent.EndOffset -gt $offset -or $stmt -isnot [System.Management.Automation.Language.IfStatementAst]) { continue }
                if ($stmt.ElseClause -or $stmt.Clauses.Count -ne 1) { continue }
                if ((Test-DryRunCondition -Condition $stmt.Clauses[0].Item1) -ne 'Dry') { continue }
                $exits = $stmt.Clauses[0].Item2.Statements | Where-Object {
                    $_ -is [System.Management.Automation.Language.ReturnStatementAst] -or
                    $_ -is [System.Management.Automation.Language.ExitStatementAst] -or
                    $_ -is [System.Management.Automation.Language.BreakStatementAst] -or
                    $_ -is [System.Management.Automation.Language.ContinueStatementAst]
                }
                if ($exits) { return $true }
            }
        }
    }
    $false
}

function Find-UnguardedMutation {
    <#
    .SYNOPSIS
    Finds state-changing Az calls in a script that a dry-run guard does not cover. Never runs the script.
    .DESCRIPTION
    Parses the script and checks every command named <Verb>-Az* whose verb is not on the read-only allow list, so an
    unlisted verb counts as mutating (fail closed). A call is guarded when it sits in the
    non-dry branch of an if on exactly $DryRun, $WhatIfPreference or their negation, or follows an early bare
    `if ($DryRun) { ...; return }`. Any other condition is unknown and guards nothing. Dynamic invocations
    (`& $cmd`) are reported as <dynamic>.
    A parse error throws, so a script that cannot be read is never reported clean.
    .EXAMPLE
    Find-UnguardedMutation -Path ./Deploy.ps1
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$ReadOnlyVerb = @('Get', 'Test', 'Find', 'Search', 'Resolve', 'Measure', 'Show', 'Select', 'Compare', 'Wait')
    )
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) { throw "Parse error in ${Path}: $($errors[0].Message)" }
    $readOnly = [System.Collections.Generic.HashSet[string]]::new([string[]]$ReadOnlyVerb, [StringComparer]::OrdinalIgnoreCase)
    $calls = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    $hits = foreach ($call in $calls) {
        $name = $call.GetCommandName()
        # `& $cmd` / `. $cmd`: the target is unknowable, so report it
        if (-not $name -and $call.InvocationOperator -in @('Ampersand', 'Dot')) { $name = '<dynamic>' }
        $bare = if ($name) { $name.Substring($name.LastIndexOf('\') + 1) }
        $mutating = $name -eq '<dynamic>' -or ($bare -match '^([A-Za-z]+)-Az' -and -not $readOnly.Contains($Matches[1]))
        if ($mutating -and -not (Test-CallGuarded -Call $call)) {
            [pscustomobject]@{ Line = [int]$call.Extent.StartLineNumber; Command = $name }
        }
    }
    @(@($hits) | Where-Object { $_ } | Sort-Object -Property Line)
}

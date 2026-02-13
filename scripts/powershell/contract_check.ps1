[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Args
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$target = Join-Path $repoRoot 'scripts\python\contract_check.py'

& python $target @Args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

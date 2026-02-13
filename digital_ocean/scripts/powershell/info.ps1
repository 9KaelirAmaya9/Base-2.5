[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Args
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
$target = Join-Path $repoRoot 'digital_ocean\scripts\python\info.py'

& python $target @Args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

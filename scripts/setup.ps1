[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = 'Stop'

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  Write-Error 'node is required. Install Node.js 18+ and re-run.'
  exit 127
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$setupJs = Join-Path $repoRoot 'scripts\setup.js'

& $node.Path $setupJs @Args
exit $LASTEXITCODE

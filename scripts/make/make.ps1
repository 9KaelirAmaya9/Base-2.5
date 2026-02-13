$ErrorActionPreference = "Stop"

$rootDir = (Resolve-Path (Join-Path $PSScriptRoot "..\.."))
$scriptPath = Join-Path $rootDir "scripts\make\make.js"

node $scriptPath @args
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
$contract = Join-Path $projectRoot 'specs/001-django-fastapi-react/contracts/openapi.yaml'
$outDir = Join-Path $projectRoot 'react-app/src/services/api'

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw 'npx is required (Node.js)'
}

New-Item -ItemType Directory -Path $outDir -Force | Out-Null
& npx openapi-typescript $contract -o (Join-Path $outDir 'types.d.ts')
Write-Host "Generated: $outDir\types.d.ts"

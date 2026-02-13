[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'docker not found'
}

Write-Host '[INFO] Restarting postgres and redis containers for chaos smoke...'
docker compose restart postgres redis

Write-Host '[INFO] Waiting 10s for services to settle...'
Start-Sleep -Seconds 10

Write-Host '[INFO] Probing API health'
try {
    Invoke-WebRequest -Uri 'http://localhost:8000/api/health' -UseBasicParsing -TimeoutSec 5 | Out-Null
} catch {
    Write-Warning 'API health probe failed (expected during chaos)'
}

Write-Host '[INFO] Done'

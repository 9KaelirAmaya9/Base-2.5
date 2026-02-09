$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$composeFile = Join-Path $projectRoot 'local.docker.yml'
$composeArgs = @('-f', $composeFile)

function Require-ComposeRunning {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        throw 'Docker is not installed or not on PATH. Run ./scripts/start.ps1 first.'
    }
    if (-not (Test-Path $composeFile)) {
        throw "Missing $composeFile. Run this script from the repo root."
    }

    $running = & docker compose @composeArgs ps --services --filter "status=running" 2>$null
    if (-not $running -or ($running -notmatch 'api')) {
        throw 'api container is not running. Run ./scripts/start.ps1 (or make up) first.'
    }
    if ($running -notmatch 'django') {
        throw 'django container is not running. Run ./scripts/start.ps1 (or make up) first.'
    }
}

Push-Location $projectRoot
try {
    Require-ComposeRunning
    docker compose -f $composeFile exec -T api pytest
    docker compose -f $composeFile exec -T django pytest

    Push-Location (Join-Path $projectRoot 'react-app')
    try {
        npm run test:ci
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
}

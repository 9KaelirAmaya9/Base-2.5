param(
    [string]$ComposeFile = 'development.docker.yml',
    [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Resolve-ComposeFilePath {
    param(
        [string]$Path,
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return (Join-Path $Root 'development.docker.yml')
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return (Join-Path $Root $Path)
}

function Resolve-EnvFilePath {
    param(
        [string]$Path,
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return (Join-Path $Root '.env')
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return (Join-Path $Root $Path)
}

$composeFile = Resolve-ComposeFilePath -Path $ComposeFile -Root $projectRoot
$envFile = Resolve-EnvFilePath -Path $EnvFile -Root $projectRoot
$composeArgs = @('--env-file', $envFile, '-f', $composeFile)
$coverageArgs = @('-e', 'COVERAGE_FILE=/tmp/.coverage')
$pytestArgs = @('-m', 'not integration and not perf')
$pytestCacheArgs = @('-o', 'cache_dir=/tmp/pytest-cache')
$apiPytestConfig = @('-c', 'api/pytest.ini')
$djangoPytestConfig = @('-c', 'pytest.ini')

function Require-ComposeRunning {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        throw 'Docker is not installed or not on PATH. Run ./scripts/start.ps1 first.'
    }
    if (-not (Test-Path $composeFile)) {
        throw "Missing $composeFile. Run this script from the repo root."
    }

    $running = @(& docker compose @composeArgs ps --services --filter "status=running" 2>$null)
    if (-not $running -or ($running -notcontains 'api')) {
        throw 'api container is not running. Run ./scripts/start.ps1 (or make up) first.'
    }
    if ($running -notcontains 'django') {
        throw 'django container is not running. Run ./scripts/start.ps1 (or make up) first.'
    }
}

Push-Location $projectRoot
try {
    Require-ComposeRunning
    if ($composeFile -and $envFile) {
        $isLocalCompose = ((Split-Path -Leaf $composeFile) -ieq 'local.docker.yml')
        $isLocalEnv = ((Split-Path -Leaf $envFile) -ieq '.env.local')
        if ($isLocalCompose -and $isLocalEnv) {
            docker compose --env-file $envFile -f $composeFile exec -T redis sh -lc 'redis-cli -a "$REDIS_PASSWORD" FLUSHALL >/dev/null 2>&1' | Out-Null
        }
    }

    docker compose --env-file $envFile -f $composeFile exec -T @coverageArgs api pytest @pytestArgs @pytestCacheArgs @apiPytestConfig
    docker compose --env-file $envFile -f $composeFile exec -T @coverageArgs django pytest @pytestArgs @pytestCacheArgs @djangoPytestConfig

    Push-Location (Join-Path $projectRoot 'react-app')
    try {
        npm run test:ci
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
}


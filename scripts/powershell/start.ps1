param(
    [switch]$Build,
    [string]$ComposeFile = 'development.docker.yml',
    [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path

function Write-Stage {
    param([string]$Label)
    Write-Host ("[STAGE] {0}" -f $Label)
}

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
$envExample = Join-Path $projectRoot '.env.example'

Write-Stage "Start.ps1 initialization"
if (-not (Test-Path $envFile)) {
    if (Test-Path $envExample) {
        Copy-Item $envExample $envFile
        Write-Host 'Created .env from .env.example (review values before deploying).'
    } else {
        throw 'Missing .env and .env.example'
    }
}

Push-Location $projectRoot
try {
    if ($Build) {
        Write-Stage "Docker compose up --build"
        docker compose --env-file $envFile -f $composeFile up -d --build
    } else {
        Write-Stage "Docker compose up"
        docker compose --env-file $envFile -f $composeFile up -d
    }
} finally {
    Pop-Location
}

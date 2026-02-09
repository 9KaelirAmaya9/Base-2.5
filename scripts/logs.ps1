param(
    [string[]]$Services,
    [int]$Tail = 200,
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

Push-Location $projectRoot
try {
    if ($Services -and $Services.Count -gt 0) {
        docker compose --env-file $envFile -f $composeFile logs -f --tail=$Tail @Services
    } else {
        docker compose --env-file $envFile -f $composeFile logs -f --tail=$Tail
    }
} finally {
    Pop-Location
}


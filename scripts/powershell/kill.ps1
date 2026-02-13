[CmdletBinding()]
param(
    [string]$ComposeFile = 'development.docker.yml',
    [string]$EnvFile = '.env',
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./scripts/powershell/kill.ps1 [OPTIONS]'
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -ComposeFile FILE  Use a specific compose file'
    Write-Output '  -EnvFile FILE      Use a specific env file'
    Write-Output '  -Force             Skip confirmation prompt'
    Write-Output '  -Help              Show this help message'
    exit 0
}

$projectRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path

function Resolve-PathSafe([string]$Path, [string]$Root, [string]$Default) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return (Join-Path $Root $Default) }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $Root $Path)
}

$composePath = Resolve-PathSafe -Path $ComposeFile -Root $projectRoot -Default 'development.docker.yml'
$envPath = Resolve-PathSafe -Path $EnvFile -Root $projectRoot -Default '.env'

if (-not (Test-Path $composePath)) { throw "Error: compose file not found: $composePath" }
if (-not (Test-Path $envPath)) { throw "Error: env file not found: $envPath" }

function Get-EnvValue([string]$Path, [string]$Key) {
    $line = Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | Where-Object { $_ -match "^${Key}=" } | Select-Object -First 1
    if ($line) {
        $line = $line -replace '\s+#.*$', ''
        return ($line -split '=', 2)[1].Trim()
    }
    return $null
}

$projectName = Get-EnvValue -Path $envPath -Key 'COMPOSE_PROJECT_NAME'
if (-not $projectName) { $projectName = Get-EnvValue -Path $envPath -Key 'PROJECT_NAME' }
if (-not $projectName) { $projectName = 'app' }
$networkName = Get-EnvValue -Path $envPath -Key 'NETWORK_NAME'
if (-not $networkName) { $networkName = "${projectName}_network" }

if (-not $Force) {
    Write-Host 'This will permanently delete containers, volumes, images, and networks.'
    $reply = Read-Host "Type 'DELETE EVERYTHING' to confirm"
    if ($reply -ne 'DELETE EVERYTHING') { throw 'Operation cancelled' }
}

Write-Host 'Starting complete removal process...'

# Stop and remove containers with volumes
try {
    docker compose --env-file $envPath -f $composePath down -v --remove-orphans
} catch { }

# Force remove remaining containers
$containers = docker ps -aq --filter "name=${projectName}_"
if ($containers) { docker rm -f $containers }

# Remove images
$images = docker images -q --filter "reference=${projectName}*"
if ($images) { docker rmi -f $images 2>$null }
$imagesAlt = docker images -q --filter "reference=*${projectName}*"
if ($imagesAlt) { docker rmi -f $imagesAlt 2>$null }

# Remove networks
$networks = docker network ls -q --filter "name=$projectName"
if ($networks) { docker network rm $networks 2>$null }
if (docker network ls --format '{{.Name}}' | Select-String -SimpleMatch $networkName) {
    docker network rm $networkName 2>$null
}

# Clean dangling resources
try {
    docker system prune -f --volumes 2>$null
} catch { }

Write-Host 'Complete removal finished.'

[CmdletBinding()]
param(
    [string]$ComposeFile = 'development.docker.yml',
    [string]$EnvFile = '.env',
    [switch]$All,
    [switch]$Volumes,
    [switch]$Images,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./scripts/powershell/clean.ps1 [OPTIONS]'
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -ComposeFile FILE  Use a specific compose file'
    Write-Output '  -EnvFile FILE      Use a specific env file'
    Write-Output '  -All               Clean containers, volumes, and images'
    Write-Output '  -Volumes           Clean volumes only (WARNING: deletes data)'
    Write-Output '  -Images            Clean images only'
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

if ($All) { $Volumes = $true; $Images = $true }

Write-Host 'Cleaning Docker Environment...'

if ($Volumes) {
    Write-Warning 'This will remove volumes and delete all data!'
    $reply = Read-Host 'Are you sure? (yes/no)'
    if ($reply -notin @('yes','y','YES','Y')) { throw 'Operation cancelled' }
    docker compose --env-file $envPath -f $composePath down -v
    Write-Host 'Containers and volumes removed.'
} else {
    docker compose --env-file $envPath -f $composePath down
    Write-Host 'Containers removed.'
}

if ($Images) {
    Write-Host 'Removing images...'
    $images = docker images --filter=reference="${projectName}*" -q
    if (-not $images) { $images = docker images --filter=reference="*${projectName}*" -q }
    if (-not $images) {
        Write-Host 'No matching images found.'
    } else {
        docker images --filter=reference="*${projectName}*"
        $reply = Read-Host 'Remove these images? (yes/no)'
        if ($reply -in @('yes','y','YES','Y')) {
            docker rmi $images
            Write-Host 'Images removed.'
        } else {
            Write-Host 'Image removal cancelled.'
        }
    }
}

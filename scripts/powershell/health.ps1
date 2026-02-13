[CmdletBinding()]
param(
    [string]$ComposeFile = 'development.docker.yml',
    [string]$EnvFile = '.env',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./scripts/powershell/health.ps1 [OPTIONS]'
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -ComposeFile FILE  Use a specific compose file'
    Write-Output '  -EnvFile FILE      Use a specific env file'
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

Write-Host 'Health Check for Docker Environment'
Write-Host ''

$running = docker compose --env-file $envPath -f $composePath ps -q
if (-not $running) {
    Write-Host 'No services are running.'
    Write-Host 'Start services: ./scripts/powershell/start.ps1'
    exit 1
}

$services = @('react-app','nginx','postgres','pgadmin','traefik')
$healthy = 0
$unhealthy = 0
$starting = 0

foreach ($service in $services) {
    $containerName = "${projectName}_$service"
    $exists = docker ps --filter "name=$containerName" --format "{{.Names}}" | Select-String -SimpleMatch $containerName
    if (-not $exists) {
        Write-Host "  $service: not running"
        $unhealthy++
        continue
    }

    $health = docker inspect --format='{{.State.Health.Status}}' $containerName 2>$null
    $status = docker inspect --format='{{.State.Status}}' $containerName 2>$null

    if ($health -eq 'healthy') {
        Write-Host "  $service: $status (healthy)"
        $healthy++
    } elseif ($health -eq 'unhealthy') {
        Write-Host "  $service: $status (unhealthy)"
        $unhealthy++
    } elseif ($health -eq 'starting') {
        Write-Host "  $service: $status (starting)"
        $starting++
    } else {
        if ($status -eq 'running') {
            Write-Host "  $service: $status"
            $healthy++
        } else {
            Write-Host "  $service: $status"
            $unhealthy++
        }
    }
}

if ($unhealthy -gt 0) { exit 1 }
if ($starting -gt 0) { exit 2 }
exit 0

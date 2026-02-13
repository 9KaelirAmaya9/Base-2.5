[CmdletBinding()]
param(
    [string]$ComposeFile = 'development.docker.yml',
    [string]$EnvFile = '.env',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./scripts/powershell/status.ps1 [OPTIONS]'
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

Write-Host 'Docker Environment Status'
Write-Host ''

docker compose --env-file $envPath -f $composePath ps

Write-Host ''
Write-Host 'Health Check Status:'

$services = @('traefik','react-app','api','django','postgres','nginx','nginx-static','pgadmin','redis','celery-worker','celery-beat','flower')
foreach ($service in $services) {
    $containerName = "${projectName}_$service"
    $exists = docker ps --filter "name=$containerName" --format "{{.Names}}" | Select-String -SimpleMatch $containerName
    if ($exists) {
        $health = docker inspect --format='{{.State.Health.Status}}' $containerName 2>$null
        $status = docker inspect --format='{{.State.Status}}' $containerName 2>$null
        if ($health -eq 'healthy') {
            Write-Host "  $service: $status (healthy)"
        } elseif ($health -eq 'unhealthy') {
            Write-Host "  $service: $status (unhealthy)"
        } elseif ($health -eq 'starting') {
            Write-Host "  $service: $status (starting)"
        } else {
            Write-Host "  $service: $status"
        }
    } else {
        Write-Host "  $service: not running"
    }
}

Write-Host ''
Write-Host 'Resource Usage:'
$containers = docker compose --env-file $envPath -f $composePath ps -q
if ($containers) {
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $containers
}

$domain = Get-EnvValue -Path $envPath -Key 'WEBSITE_DOMAIN'
if (-not $domain) { $domain = 'localhost' }
$traefikLabel = Get-EnvValue -Path $envPath -Key 'TRAEFIK_DNS_LABEL'
if (-not $traefikLabel) { $traefikLabel = 'traefik' }
$adminLabel = Get-EnvValue -Path $envPath -Key 'DJANGO_ADMIN_DNS_LABEL'
if (-not $adminLabel) { $adminLabel = 'admin' }

Write-Host ''
Write-Host 'Service URLs (via Traefik):'
Write-Host "  - Frontend:          https://$domain/"
Write-Host "  - API health:        https://$domain/api/health"
Write-Host "  - Static:            https://$domain/static/"
Write-Host "  - Traefik Dashboard: https://$traefikLabel.$domain/ (guarded)"
Write-Host "  - Django Admin:      https://$adminLabel.$domain/admin (guarded)"

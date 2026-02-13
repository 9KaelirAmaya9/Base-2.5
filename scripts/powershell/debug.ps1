[CmdletBinding()]
param(
    [string]$Service,
    [string]$ComposeFile = 'development.docker.yml',
    [string]$EnvFile = '.env',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./scripts/powershell/debug.ps1 [SERVICE]'
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
$networkName = Get-EnvValue -Path $envPath -Key 'NETWORK_NAME'
if (-not $networkName) { $networkName = "${projectName}_network" }

if ($Service) {
    $containerName = "${projectName}_$Service"
    if (-not (docker ps -a --filter "name=$containerName" --format "{{.Names}}" | Select-String -SimpleMatch $containerName)) {
        throw "Container $containerName not found"
    }

    Write-Host "Debugging service: $Service"
    Write-Host ''
    docker inspect $containerName --format='Container: {{.Name}}
Status: {{.State.Status}}
Started: {{.State.StartedAt}}
Health: {{.State.Health.Status}}
Image: {{.Config.Image}}'

    Write-Host ''
    Write-Host 'Environment Variables:'
    docker inspect $containerName --format='{{range .Config.Env}}{{println .}}{{end}}' | Sort-Object

    Write-Host ''
    Write-Host 'Port Mappings:'
    docker port $containerName 2>$null

    Write-Host ''
    Write-Host 'Networks:'
    docker inspect $containerName --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}: {{$v.IPAddress}}{{println}}{{end}}'

    Write-Host ''
    Write-Host 'Volumes:'
    docker inspect $containerName --format='{{range .Mounts}}{{.Type}}: {{.Source}} -> {{.Destination}}{{println}}{{end}}'

    Write-Host ''
    Write-Host 'Recent Logs (last 20 lines):'
    docker logs --tail 20 $containerName
} else {
    Write-Host 'Debugging all services'
    Write-Host ''
    docker compose --env-file $envPath -f $composePath ps

    Write-Host ''
    Write-Host 'Network Information:'
    docker network inspect $networkName --format='Network: {{.Name}}
Driver: {{.Driver}}
Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}

Connected Containers:
{{range $k, $v := .Containers}}  - {{$v.Name}} ({{$v.IPv4Address}})
{{end}}' 2>$null

    Write-Host ''
    Write-Host 'Volume Information:'
    docker volume ls --filter "name=$projectName" --format "table {{.Name}}	{{.Driver}}	{{.Mountpoint}}"

    Write-Host ''
    Write-Host 'Resource Usage:'
    $containers = docker compose --env-file $envPath -f $composePath ps -q
    if ($containers) {
        docker stats --no-stream $containers
    } else {
        Write-Host 'No running containers'
    }
}

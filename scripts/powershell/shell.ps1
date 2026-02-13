[CmdletBinding()]
param(
    [string]$Service,
    [switch]$Bash,
    [string]$EnvFile = '.env',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./scripts/powershell/shell.ps1 [OPTIONS] SERVICE'
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -Bash             Use bash instead of sh (if available)'
    Write-Output '  -EnvFile FILE     Use a specific env file'
    Write-Output '  -Help             Show this help message'
    exit 0
}

if (-not $Service) { throw 'SERVICE argument is required' }

$projectRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
$envPath = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $projectRoot $EnvFile }

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

$containerName = "${projectName}_$Service"

if (-not (docker ps --filter "name=$containerName" --format "{{.Names}}" | Select-String -SimpleMatch $containerName)) {
    throw "Container $containerName is not running"
}

if ($Bash) {
    docker exec -it $containerName bash 2>$null
    if ($LASTEXITCODE -ne 0) {
        docker exec -it $containerName sh
    }
} else {
    docker exec -it $containerName sh
}

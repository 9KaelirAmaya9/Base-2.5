[CmdletBinding()]
param(
    [string]$ComposeFile = 'development.docker.yml',
    [string]$EnvFile = '.env',
    [switch]$NoCache,
    [string]$Service,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./scripts/powershell/rebuild.ps1 [OPTIONS] [SERVICE]'
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -ComposeFile FILE  Use a specific compose file'
    Write-Output '  -EnvFile FILE      Use a specific env file'
    Write-Output '  -NoCache           Build without using cache'
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

$args = @('compose','--env-file',$envPath,'-f',$composePath,'build')
if ($NoCache) { $args += '--no-cache' }
if ($Service) { $args += $Service }

Write-Host 'Rebuilding Docker Environment...'

& docker @args

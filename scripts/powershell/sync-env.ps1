[CmdletBinding()]
param(
    [string]$ComposeFile = 'development.docker.yml',
    [string]$EnvFile = '.env',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./scripts/powershell/sync-env.ps1 [OPTIONS]'
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -ComposeFile FILE  Use a specific compose file'
    Write-Output '  -EnvFile FILE      Use a specific env file'
    Write-Output '  -Help              Show this help message'
    exit 0
}

$projectRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
$composePath = if ([System.IO.Path]::IsPathRooted($ComposeFile)) { $ComposeFile } else { Join-Path $projectRoot $ComposeFile }
$envPath = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $projectRoot $EnvFile }

if (-not (Test-Path $composePath)) { throw "Error: compose file not found: $composePath" }
if (-not (Test-Path $envPath)) {
    $envExample = Join-Path $projectRoot '.env.example'
    if (Test-Path $envExample) {
        Copy-Item $envExample $envPath
    } else {
        throw 'Error: .env.example not found. Cannot create .env.'
    }
}

function Get-EnvValue([string]$Path, [string]$Key) {
    $line = Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | Where-Object { $_ -match "^${Key}=" } | Select-Object -First 1
    if ($line) {
        $line = $line -replace '\s+#.*$', ''
        return ($line -split '=', 2)[1].Trim()
    }
    return $null
}

$networkName = Get-EnvValue -Path $envPath -Key 'NETWORK_NAME'
if (-not $networkName) { throw 'NETWORK_NAME not set in .env' }

$envText = Get-Content -LiteralPath $envPath -Raw -Encoding UTF8
$envText = [System.Text.RegularExpressions.Regex]::Replace($envText, '(?m)^\s*TRAEFIK_DOCKER_NETWORK\s*=.*\r?\n?', '')
if (-not $envText.EndsWith("`r`n")) { $envText += "`r`n" }
$envText += "TRAEFIK_DOCKER_NETWORK=$networkName`r`n"
$envText | Set-Content -LiteralPath $envPath -Encoding UTF8

$composeText = Get-Content -LiteralPath $composePath -Raw -Encoding UTF8

if ($composeText -notmatch '(?m)^networks:\s*$') {
    Write-Warning "No networks block found in $composePath"
} else {
    $match = [regex]::Match($composeText, '(?ms)^networks:\s*\r?\n\s{2}([A-Za-z0-9_-]+):')
    if ($match.Success) {
        $currentKey = $match.Groups[1].Value
        if ($currentKey -ne 'app_network') {
            $composeText = $composeText -replace "(?m)^  $currentKey:", '  app_network:'
            $composeText = $composeText -replace "(?m)^\s*- $currentKey\s*$", '  - app_network'
        }
    }

    if ($composeText -notmatch '(?ms)^  app_network:\s*\r?\n\s+name:\s*\$\{NETWORK_NAME\}') {
        $composeText = $composeText -replace '(?ms)^  app_network:\s*\r?\n', "  app_network:`r`n    name: `\$\{NETWORK_NAME\}`r`n"
    }
}

$composeText | Set-Content -LiteralPath $composePath -Encoding UTF8

Write-Host 'Sync completed.'

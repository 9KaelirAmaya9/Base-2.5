[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if (-not $env:VIRTUAL_ENV) {
    throw 'Virtual environment not active. Run ./scripts/first-start.ps1 to activate `.venv` before installing Node dependencies.'
}

Write-Host '==> Node dependency installation starting' -ForegroundColor Cyan

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    throw 'node executable not found in PATH. Install Node.js 18+ and retry.'
}

$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npmCmd) {
    throw 'npm executable not found in PATH. Install npm 9+ and retry.'
}

function Get-NumericVersion([string]$version) {
    if (-not $version) { return @() }
    $trimmed = $version.TrimStart('v').Trim()
    if (-not $trimmed) { return @() }
    $numbers = @()
    foreach ($segment in ($trimmed -split '\.')) {
        if ($segment -match '^[0-9]+$') {
            $numbers += [int]$segment
        }
    }
    return $numbers
}

$nodeVersionParts = @(Get-NumericVersion (& $nodeCmd.Path --version))
if ($nodeVersionParts.Count -lt 1) {
    throw 'Unable to parse node --version output.'
}

$minimumNodeMajor = 18

if ($nodeVersionParts[0] -lt $minimumNodeMajor) {
    throw "Node.js major version $minimumNodeMajor+ is required but found $($nodeVersionParts[0])."
}

$npmVersionParts = @(Get-NumericVersion (& $npmCmd.Path --version))
if ($npmVersionParts.Count -lt 1) {
    throw 'Unable to parse npm --version output.'
}

$requiredNpmMajor = 9
if ($npmVersionParts[0] -lt $requiredNpmMajor) {
    throw "npm version $requiredNpmMajor+ required but found $($npmVersionParts[0])."
}

Write-Host ("Node version: {0}; npm version: {1}" -f (& $nodeCmd.Path --version).Trim(), (& $npmCmd.Path --version).Trim()) -ForegroundColor DarkGray

function Invoke-NpmInstall([string]$workingDir, [string]$label, [switch]$AllowLegacyPeerDeps) {
    Push-Location $workingDir
    try {
        & $npmCmd.Path install --no-fund
        if ($LASTEXITCODE -ne 0) {
            if ($AllowLegacyPeerDeps) {
                Write-Warning "npm install ($label) failed; retrying with --legacy-peer-deps."
                & $npmCmd.Path install --no-fund --legacy-peer-deps
            }
            if ($LASTEXITCODE -ne 0) {
                throw "npm install ($label) failed with exit code $LASTEXITCODE"
            }
        }
    } finally {
        Pop-Location
    }
}

Write-Host "Installing npm dependencies in $repoRoot..." -ForegroundColor Cyan
Invoke-NpmInstall -workingDir $repoRoot -label 'repo root'

$subdirs = @('react-app','e2e')
foreach ($sub in $subdirs) {
    $pkgJson = Join-Path $repoRoot "$sub/package.json"
    if (Test-Path $pkgJson) {
        Write-Host "Installing npm dependencies in $sub..." -ForegroundColor Cyan
        $allowLegacy = $sub -eq 'react-app'
        Invoke-NpmInstall -workingDir (Join-Path $repoRoot $sub) -label $sub -AllowLegacyPeerDeps:$allowLegacy
    }
}

Write-Host 'Node dependencies installed successfully.' -ForegroundColor Green

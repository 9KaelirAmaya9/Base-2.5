[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    throw 'python executable not found in PATH. Install Python 3.12+ and retry.'
}

$venvDir = Join-Path $repoRoot '.venv'
$venvPython = Join-Path $venvDir 'Scripts\python.exe'
$needsCreate = $Force -or -not (Test-Path $venvPython)

if ($needsCreate) {
    Write-Host 'Creating Python virtual environment (.venv)...' -ForegroundColor Cyan
    & $pythonCmd.Path -m venv $venvDir
    if ($LASTEXITCODE -ne 0) {
        throw "python -m venv failed with exit code $LASTEXITCODE"
    }
} else {
    Write-Host 'Existing Python virtual environment detected.' -ForegroundColor DarkGreen
}

Write-Host "Virtual environment ready at: $venvPython" -ForegroundColor Green

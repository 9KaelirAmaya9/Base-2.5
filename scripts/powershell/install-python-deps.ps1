[CmdletBinding()]
param(
    [switch]$SkipPipUpgrade,
    [switch]$Api,
    [switch]$Django,
    [switch]$DigitalOcean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
$venvPython = Join-Path $repoRoot '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    throw 'Virtual environment .venv not found. Run ./scripts/powershell/bootstrap-venv.ps1 first.'
}

Write-Host '==> Python dependency installation starting' -ForegroundColor Cyan

$requiredVersion = '3.12'
$pythonVersionFile = Join-Path $repoRoot '.python-version'
if (Test-Path $pythonVersionFile) {
    $content = (Get-Content $pythonVersionFile -ErrorAction Stop | Select-Object -First 1).Trim()
    if ($content) { $requiredVersion = $content }
}

function Normalize-Version([string]$version) {
    if (-not $version) { return '' }
    $parts = $version.TrimStart('v').Trim() -split '\.'
    if ($parts.Count -ge 2) {
        return "$($parts[0]).$($parts[1])"
    }
    return $version.Trim()
}

$actualVersion = (& $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
if (-not $actualVersion) {
    throw 'Unable to determine Python version from virtual environment.'
}

$expectedVersion = Normalize-Version $requiredVersion
if (-not $expectedVersion) {
    throw 'Unable to determine required Python version.'
}

if ($actualVersion -ne $expectedVersion) {
    throw "Virtual environment uses Python $actualVersion but $expectedVersion is required."
}

if (-not $SkipPipUpgrade) {
    Write-Host 'Upgrading pip...' -ForegroundColor Cyan
    & $venvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        throw "pip upgrade failed with exit code $LASTEXITCODE"
    }
}

$requirements = @()
$apiReq = 'requirements-dev-api.txt'
$djangoReq = 'requirements-dev-django.txt'
$doReq = 'digital_ocean/requirements.txt'

if ($Api -or $Django -or $DigitalOcean) {
    if ($Api) { $requirements += $apiReq }
    if ($Django) { $requirements += $djangoReq }
    if ($DigitalOcean) { $requirements += $doReq }
} else {
    # Default to DigitalOcean automation deps for first-start.
    $requirements += $doReq
}

foreach ($req in $requirements) {
    $reqPath = Join-Path $repoRoot $req
    if (Test-Path $reqPath) {
        Write-Host "Installing Python dependencies from $req..." -ForegroundColor Cyan
        & $venvPython -m pip install -r $reqPath
        if ($LASTEXITCODE -ne 0) {
            throw "pip install -r $req failed with exit code $LASTEXITCODE"
        }
    } else {
        throw "Requirements file not found: $req"
    }
}

Write-Host 'Python dependencies installed successfully.' -ForegroundColor Green

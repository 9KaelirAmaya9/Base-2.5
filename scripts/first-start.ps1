[CmdletBinding()]
param(
    [switch]$ForceVenv,
    [switch]$SkipSetup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$bootstrapScript = Join-Path $PSScriptRoot 'bootstrap-venv.ps1'
$pythonDepsScript = Join-Path $PSScriptRoot 'install-python-deps.ps1'
$nodeDepsScript = Join-Path $PSScriptRoot 'install-node-deps.ps1'
$setupScript = Join-Path $PSScriptRoot 'setup.ps1'

Push-Location $repoRoot
try {
    Write-Host '==> Starting first-start orchestration' -ForegroundColor Cyan
    $bootstrapArgs = @()
    if ($ForceVenv) { $bootstrapArgs += '-Force' }
    Write-Host '==> Bootstrapping virtual environment' -ForegroundColor Cyan
    try {
        & $bootstrapScript @bootstrapArgs
        Write-Host 'OK: Virtual environment ready' -ForegroundColor Green
    } catch {
        Write-Error "Venv bootstrap failed: $($_.Exception.Message)"
        throw
    }

    $activateScript = Join-Path $repoRoot '.venv\Scripts\Activate.ps1'
    if (-not (Test-Path $activateScript)) {
        throw 'Activate script not found. Ensure the venv was created successfully.'
    }

    Write-Host '==> Activating virtual environment' -ForegroundColor Cyan
    . $activateScript

    if (-not $env:VIRTUAL_ENV) {
        throw 'Virtual environment activation failed. The VIRTUAL_ENV variable is not set.'
    }

    $resolvedVenv = (Resolve-Path $env:VIRTUAL_ENV).Path
    $expectedVenv = (Resolve-Path (Join-Path $repoRoot '.venv')).Path
    if ($resolvedVenv -ne $expectedVenv) {
        throw "Unexpected virtual environment active: $resolvedVenv (expected $expectedVenv)."
    }

    Write-Host '==> Installing Python dependencies' -ForegroundColor Cyan
    try {
        & $pythonDepsScript
        Write-Host 'OK: Python dependencies installed' -ForegroundColor Green
    } catch {
        Write-Error "Python dependency install failed: $($_.Exception.Message)"
        throw
    }

    Write-Host '==> Installing Node dependencies' -ForegroundColor Cyan
    try {
        & $nodeDepsScript
        Write-Host 'OK: Node dependencies installed' -ForegroundColor Green
    } catch {
        Write-Error "Node dependency install failed: $($_.Exception.Message)"
        throw
    }

    if (-not $SkipSetup) {
        Write-Host '==> Running guided setup (.env generation)' -ForegroundColor Cyan
        try {
            & $setupScript
            if ($LASTEXITCODE -ne 0) {
                throw "setup.ps1 exited with code $LASTEXITCODE"
            }
            Write-Host 'OK: Setup completed' -ForegroundColor Green
        } catch {
            Write-Error "Setup failed: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-Host '==> Skipping guided setup (--SkipSetup)' -ForegroundColor DarkYellow
    }

    Write-Host '==> First-start completed successfully' -ForegroundColor Green
} finally {
    Pop-Location
}

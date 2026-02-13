<#!
.SYNOPSIS
    One-time onboarding orchestrator for local tooling and .env generation.

.DESCRIPTION
    Runs the full local bootstrap in a single, ordered flow:
    1) scripts/powershell/bootstrap-venv.ps1 (create or recreate .venv)
    2) Activate .venv for the current PowerShell session
    3) scripts/powershell/install-python-deps.ps1 (Python deps for automation)
    4) scripts/powershell/install-node-deps.ps1 (Node deps for root/react-app/e2e)
    5) scripts/powershell/setup.ps1 (guided .env generation from .env.example)

    The setup step may prompt to overwrite .env and/or request required values
    (DigitalOcean token, domain, emails, etc.). You can also edit .env manually
    after it is generated.

.PARAMETER ForceVenv
    Recreate the .venv even if one already exists.

.PARAMETER SkipSetup
    Skip running scripts/powershell/setup.ps1. Use this if you only need dependency hydration.

.SETUP_OPTIONS
    scripts/powershell/setup.ps1 supports additional options when you need fine control.
    Run setup.ps1 directly after first-start if you need any of these:

    -NonInteractive   Run setup.js in non-interactive mode (best for CI).
    -SkipSetupJs      Skip setup.js and only run secret generation + DO SSH sync.
    -EnvPath <path>   Target a different .env file (default: repo root .env).
    -DoSyncDryRun     Dry-run the DigitalOcean SSH key sync step.
    <args...>         Any extra args are passed to setup.js (ValueFromRemainingArguments).

    Why these exist:
    - NonInteractive lets automation run without prompts.
    - SkipSetupJs is useful if .env already exists and you only want secrets/SSH sync.
    - EnvPath lets you manage multiple environments (e.g., .env.staging).
    - DoSyncDryRun lets you verify SSH key actions without touching DO.
    - Extra args let you control setup.js prompts/behavior.

.EXAMPLE
    ./scripts/powershell/first-start.ps1

.EXAMPLE
    ./scripts/powershell/first-start.ps1 -ForceVenv

.EXAMPLE
    ./scripts/powershell/first-start.ps1 -SkipSetup

.EXAMPLE
    # Run first-start, then run setup with extra options
    ./scripts/powershell/first-start.ps1 -SkipSetup
    ./scripts/powershell/setup.ps1 -NonInteractive -EnvPath .\.env.staging -DoSyncDryRun

.NOTES
    Keep the PowerShell session open so the activated .venv remains in effect.
#>
[CmdletBinding()]
param(
    [switch]$ForceVenv,
    [switch]$SkipSetup,
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host 'Usage: ./scripts/powershell/first-start.ps1 [options]' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Options:'
    Write-Host '  -ForceVenv   Recreate the .venv even if one already exists'
    Write-Host '  -SkipSetup  Skip running scripts/powershell/setup.ps1'
    Write-Host '  -Help, -h   Show this help'
    Write-Host ''
    Write-Host 'Tip: run ./scripts/powershell/setup.ps1 -Help for setup options.'
    return
}

$repoRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
$bootstrapScript = Join-Path $PSScriptRoot 'bootstrap-venv.ps1'
$pythonDepsScript = Join-Path $PSScriptRoot 'install-python-deps.ps1'
$nodeDepsScript = Join-Path $PSScriptRoot 'install-node-deps.ps1'
$setupScript = Join-Path $PSScriptRoot 'setup.ps1'

Push-Location $repoRoot
try {
    Write-Host '==> Starting first-start orchestration' -ForegroundColor Cyan
    Write-Host '==> Steps: bootstrap-venv, activate .venv, install python deps, install node deps, run setup (.env generation)' -ForegroundColor DarkGray
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
        Write-Host 'NOTE: setup.ps1 may prompt to overwrite .env and ask for required values (e.g., DO token, domain, emails).' -ForegroundColor DarkGray
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

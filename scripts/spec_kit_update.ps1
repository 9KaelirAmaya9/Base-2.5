param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$envPath = Join-Path $repoRoot '.env'
if (-not (Test-Path $envPath)) {
    throw "Missing $envPath. Add SPEC_KIT_AI and SPEC_KIT_SCRIPT to .env."
}

$src = Join-Path $repoRoot '.specify/memory/constitution.md'
$specifyBackup = Join-Path $repoRoot '.specify/memory/constitution-backup.md'
$tmpDir = Join-Path $repoRoot 'tmp'
$tmpBackup = Join-Path $tmpDir 'constitution-backup.md'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$specifyBackupStamped = Join-Path $repoRoot ".specify/memory/constitution-backup-$timestamp.md"
$tmpBackupStamped = Join-Path $tmpDir "constitution-backup-$timestamp.md"

$specKitVars = @{}
Get-Content $envPath | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) {
        return
    }
    $pair = $line -split '=', 2
    if ($pair.Length -ne 2) {
        return
    }
    $key = $pair[0].Trim()
    $value = $pair[1].Trim()
    if ($key -eq 'SPEC_KIT_AI' -or $key -eq 'SPEC_KIT_SCRIPT') {
        $specKitVars[$key] = $value
    }
}

$specKitAi = $specKitVars['SPEC_KIT_AI']
$specKitScript = $specKitVars['SPEC_KIT_SCRIPT']
if ([string]::IsNullOrWhiteSpace($specKitAi) -or [string]::IsNullOrWhiteSpace($specKitScript)) {
    throw 'Missing SPEC_KIT_AI or SPEC_KIT_SCRIPT in .env. Add these keys.'
}

if (-not (Test-Path $src)) {
    throw "Missing $src. Run this from the base2 repo root after spec-kit has generated memory."
}

Write-Host "[spec-kit-update] Repo root: $repoRoot"
Write-Host "[spec-kit-update] Backup source: $src"

if ($DryRun) {
    Write-Host "[spec-kit-update] DRY RUN: would ensure directory $tmpDir"
    Write-Host "[spec-kit-update] DRY RUN: would copy $src -> $specifyBackup"
    Write-Host "[spec-kit-update] DRY RUN: would copy $src -> $tmpBackup"
    Write-Host "[spec-kit-update] DRY RUN: would copy $src -> $specifyBackupStamped"
    Write-Host "[spec-kit-update] DRY RUN: would copy $src -> $tmpBackupStamped"
    Write-Host "[spec-kit-update] DRY RUN: would run: uv tool install specify-cli --force --from git+https://github.com/github/spec-kit.git"
    Write-Host "[spec-kit-update] DRY RUN: would run: specify init --here --force --ai $specKitAi --script $specKitScript"
    return
}

New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
Copy-Item -Path $src -Destination $specifyBackup -Force
Copy-Item -Path $src -Destination $tmpBackup -Force
Copy-Item -Path $src -Destination $specifyBackupStamped -Force
Copy-Item -Path $src -Destination $tmpBackupStamped -Force

uv tool install specify-cli --force --from git+https://github.com/github/spec-kit.git
if ($LASTEXITCODE -ne 0) {
    throw 'spec-kit not install'
}

specify init --here --force --ai $specKitAi --script $specKitScript
if ($LASTEXITCODE -ne 0) {
    throw 'spec-kit not install'
}

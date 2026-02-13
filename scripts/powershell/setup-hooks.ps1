[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
Set-Location $projectRoot

Write-Host 'Setting up git hooks...'

if (-not (Test-Path '.git')) {
    throw 'Error: Not a git repository. Initialize git first: git init'
}

New-Item -ItemType Directory -Path '.git/hooks' -Force | Out-Null

$hookSource = Join-Path $projectRoot '.git-hooks/pre-commit'
$hookDest = Join-Path $projectRoot '.git/hooks/pre-commit'

if (Test-Path $hookSource) {
    Copy-Item $hookSource $hookDest -Force
    Write-Host 'Pre-commit hook installed.'
} else {
    Write-Warning 'Warning: .git-hooks/pre-commit not found'
}

Write-Host 'Git hooks setup complete.'

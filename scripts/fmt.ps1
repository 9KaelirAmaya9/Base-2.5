$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$venvPython = Join-Path $projectRoot '.venv\Scripts\python.exe'

Push-Location $projectRoot
try {
    Push-Location (Join-Path $projectRoot 'react-app')
    try {
        npm run format
    } finally {
        Pop-Location
    }

    if (Test-Path $venvPython) {
        & $venvPython -m ruff format .
    } else {
        python -m ruff format .
    }
} finally {
    Pop-Location
}

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$venvPython = Join-Path $projectRoot '.venv\Scripts\python.exe'

Push-Location $projectRoot
try {
    Push-Location (Join-Path $projectRoot 'react-app')
    try {
        npm run lint
    } finally {
        Pop-Location
    }

    if (Test-Path $venvPython) {
        & $venvPython -m ruff check .
    } else {
        python -m ruff check .
    }
} finally {
    Pop-Location
}

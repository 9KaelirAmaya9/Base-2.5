[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
$maxBytes = 5MB

function Fail([string]$Message) {
    Write-Error "[repo-guard] FAIL: $Message"
    exit 1
}

Push-Location $repoRoot
try {
    if (git ls-files --error-unmatch docker-compose 2>$null) {
        Fail 'Tracked forbidden file: docker-compose'
    }

    if (git ls-files | Select-String -Pattern '\.exe$') {
        Fail 'Tracked forbidden executable(s): *.exe'
    }

    if (git ls-files | Select-String -Pattern '(\.pyc$|/__pycache__/)' ) {
        Fail 'Tracked Python bytecode artifacts (*.pyc or __pycache__).'
    }

    $files = git ls-files
    foreach ($file in $files) {
        $path = Join-Path $repoRoot $file
        if (-not (Test-Path $path)) { continue }
        $size = (Get-Item $path).Length
        if ($size -gt $maxBytes) {
            Fail "Tracked file too large (>5MB): $file ($size bytes)"
        }
    }

    foreach ($file in $files) {
        if ($file -match '[/\\]') { continue }
        $path = Join-Path $repoRoot $file
        if (-not (Test-Path $path)) { continue }
        $bytes = [System.IO.File]::ReadAllBytes($path)
        if ($bytes.Length -ge 4) {
            if ($bytes[0] -eq 0x7F -and $bytes[1] -eq 0x45 -and $bytes[2] -eq 0x4C -and $bytes[3] -eq 0x46) {
                Fail "Binary file tracked at repo root: $file (ELF)"
            }
            if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
                Fail "Binary file tracked at repo root: $file (PE)"
            }
        }
    }

    Write-Host '[repo-guard] OK'
} finally {
    Pop-Location
}

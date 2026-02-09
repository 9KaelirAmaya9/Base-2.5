[CmdletBinding()]
param(
  [string]$KeyName,
  [string]$SshDir,
  [switch]$DryRun,
  [switch]$Force,
  [switch]$RecreateLocal,
  [switch]$RecreateRemote,
  [string]$PythonExe = "python"
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$msg) {
  Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Info([string]$msg) {
  Write-Host "[INFO] $msg" -ForegroundColor Gray
}

function Get-DoKeysByName([string]$name) {
  $args = @('-m', 'digital_ocean.DO_ssh_keys', '--find', '--name', $name, '--json')
  $tmpStdout = Join-Path $env:TEMP "do-ssh-find-out-$PID.txt"
  $tmpStderr = Join-Path $env:TEMP "do-ssh-find-err-$PID.txt"
  $argLine = $args -join ' '
  $proc = Start-Process -FilePath $PythonExe -ArgumentList $argLine -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmpStdout -RedirectStandardError $tmpStderr
  $stdoutLines = @()
  $stderrLines = @()
  if (Test-Path $tmpStdout) { $stdoutLines += Get-Content -Path $tmpStdout -ErrorAction SilentlyContinue }
  if (Test-Path $tmpStderr) { $stderrLines += Get-Content -Path $tmpStderr -ErrorAction SilentlyContinue }
  if ($stdoutLines) { $stdoutLines | ForEach-Object { Write-Host "[DO] $_" } }
  if ($stderrLines) { $stderrLines | ForEach-Object { Write-Host "[DO] $_" } }
  if ($proc.ExitCode -ne 0) {
    throw "DO_ssh_keys find failed with exit code $($proc.ExitCode)"
  }
  try {
    $combined = ($stdoutLines + $stderrLines) -join "`n"
    $match = [regex]::Match($combined, '\[[\s\S]*\]')
    if ($match.Success) {
      $payload = $match.Value.Trim()
      if ($payload) {
        $parsed = $payload | ConvertFrom-Json -ErrorAction Stop
        return @($parsed)
      }
    }
  } catch {
    Write-Info 'Could not parse DO_ssh_keys find output.'
  }
  return @()
}

function Remove-DoKey([string]$keyId, [string]$fingerprint) {
  $args = @('-m', 'digital_ocean.DO_ssh_keys', '--delete', '--yes', '--json')
  if ($keyId) {
    $args += @('--id', $keyId)
  } elseif ($fingerprint) {
    $args += @('--fingerprint', $fingerprint)
  } else {
    return
  }
  $tmpStdout = Join-Path $env:TEMP "do-ssh-del-out-$PID.txt"
  $tmpStderr = Join-Path $env:TEMP "do-ssh-del-err-$PID.txt"
  $argLine = $args -join ' '
  $proc = Start-Process -FilePath $PythonExe -ArgumentList $argLine -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmpStdout -RedirectStandardError $tmpStderr
  $output = @()
  if (Test-Path $tmpStdout) { $output += Get-Content -Path $tmpStdout -ErrorAction SilentlyContinue }
  if (Test-Path $tmpStderr) { $output += Get-Content -Path $tmpStderr -ErrorAction SilentlyContinue }
  if ($output) { $output | ForEach-Object { Write-Host "[DO] $_" } }
  if ($proc.ExitCode -ne 0) {
    throw "DO_ssh_keys delete failed with exit code $($proc.ExitCode)"
  }
}

function Get-LocalPublicKey([string]$path) {
  if (-not (Test-Path $path)) {
    return $null
  }
  return (Get-Content -Path $path -ErrorAction SilentlyContinue | Select-Object -First 1)
}

$userProfile = $env:USERPROFILE
if (-not $userProfile) {
  $userProfile = [Environment]::GetFolderPath('UserProfile')
}

function Get-EnvFromDotEnv([string]$key, [string]$rootDir) {
  $envPath = Join-Path $rootDir '.env'
  if (-not (Test-Path $envPath)) {
    return $null
  }
  foreach ($line in Get-Content -Path $envPath) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
    $m = [regex]::Match($trimmed, '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$')
    if (-not $m.Success) { continue }
    if ($m.Groups[1].Value -eq $key) {
      return $m.Groups[2].Value
    }
  }
  return $null
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')

if (-not $SshDir) {
  $SshDir = Join-Path $userProfile '.ssh'
}

if (-not $KeyName) {
  $projectName = $env:PROJECT_NAME
  if (-not $projectName) {
    $projectName = Get-EnvFromDotEnv -key 'PROJECT_NAME' -rootDir $repoRoot
  }
  $KeyName = if ($projectName) { $projectName } else { 'do-ssh' }
}

$privateKeyPath = Join-Path $SshDir $KeyName
$publicKeyPath = "$privateKeyPath.pub"

Write-Step "Preparing SSH key for user '$userProfile'"
Write-Info "SSH directory: $SshDir"
Write-Info "Key name: $KeyName"
Write-Info "Private key: $privateKeyPath"
Write-Info "Public key:  $publicKeyPath"

if ($DryRun) {
  Write-Info 'Dry-run: will create local key to show output, then delete local files. No API calls.'
}

if ($RecreateLocal) {
  Write-Info 'RecreateLocal: will delete and re-create local SSH key files.'
}

if ($RecreateRemote) {
  Write-Info 'RecreateRemote: will delete and re-create the DigitalOcean SSH key.'
}

if (-not (Test-Path $SshDir)) {
  if ($DryRun) {
    Write-Info "Dry-run: would create directory $SshDir"
  } else {
    New-Item -ItemType Directory -Path $SshDir | Out-Null
  }
}

$privateExists = Test-Path $privateKeyPath
$publicExists = Test-Path $publicKeyPath

if ($RecreateLocal) {
  if ($DryRun) {
    Write-Info "Dry-run: would remove existing key files at $privateKeyPath and $publicKeyPath"
  } else {
    if ($privateExists) { Remove-Item -Force $privateKeyPath }
    if ($publicExists) { Remove-Item -Force $publicKeyPath }
  }
  $privateExists = $false
  $publicExists = $false
} elseif ($privateExists -or $publicExists) {
  if ($Force) {
    if ($DryRun) {
      Write-Info "Dry-run: would remove existing key files at $privateKeyPath and $publicKeyPath"
    } else {
      if ($privateExists) { Remove-Item -Force $privateKeyPath }
      if ($publicExists) { Remove-Item -Force $publicKeyPath }
    }
  } else {
    if ($DryRun) {
      $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
      $KeyName = "$KeyName-dryrun-$timestamp"
      $privateKeyPath = Join-Path $SshDir $KeyName
      $publicKeyPath = "$privateKeyPath.pub"
      Write-Info "Dry-run: existing key detected; using temp key name $KeyName"
    } else {
      Write-Info 'SSH key already exists; will reuse it.'
    }
  }
}

$privateExists = Test-Path $privateKeyPath
$publicExists = Test-Path $publicKeyPath
$createdLocal = $false
$createdRemote = $false
$createdKeyId = $null
$createdFingerprint = $null
$doOutput = @()

if (-not $privateExists -or -not $publicExists) {
  $sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue
  if (-not $sshKeygen) {
    Write-Error 'ssh-keygen not found in PATH. Install OpenSSH client or use an existing key.'
    exit 127
  }

  if ($DryRun) {
    Write-Step 'Generating SSH key pair (dry-run executes then cleans up)'
  } else {
    Write-Step 'Generating SSH key pair'
  }
  $tmpStdout = Join-Path $env:TEMP "ssh-keygen-out-$PID.txt"
  $tmpStderr = Join-Path $env:TEMP "ssh-keygen-err-$PID.txt"
  $argLine = "-t ed25519 -f `"$privateKeyPath`" -N `"`" -C `"$KeyName`""
  $proc = Start-Process -FilePath $sshKeygen.Path -ArgumentList $argLine -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmpStdout -RedirectStandardError $tmpStderr
  $sshOutput = @()
  if (Test-Path $tmpStdout) { $sshOutput += Get-Content -Path $tmpStdout -ErrorAction SilentlyContinue }
  if (Test-Path $tmpStderr) { $sshOutput += Get-Content -Path $tmpStderr -ErrorAction SilentlyContinue }
  if ($sshOutput) {
    $sshOutput | ForEach-Object { Write-Host "[SSH] $_" }
  }
  if ($proc.ExitCode -ne 0) {
    throw "ssh-keygen failed with exit code $($proc.ExitCode)"
  }
  $createdLocal = $true
}

if (-not $DryRun -and (Test-Path $publicKeyPath)) {
  Write-Step 'SSH key created'
  $pubLine = (Get-Content -Path $publicKeyPath -ErrorAction SilentlyContinue | Select-Object -First 1)
  if ($pubLine) {
    Write-Info "Public key: $pubLine"
  }
  $sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue
  if ($sshKeygen) {
    $fp = & $sshKeygen.Path -lf $publicKeyPath 2>&1
    if ($fp) {
      $fp | ForEach-Object { Write-Host "[SSH] $_" }
    }
  }
}

try {
  if ($DryRun) {
    Write-Step 'Dry-run: skipping DigitalOcean registration'
    if ($RecreateRemote) {
      Write-Info "Dry-run: would delete existing DigitalOcean SSH key(s) named $KeyName"
    }
    Write-Info "Dry-run: would run $PythonExe -m digital_ocean.DO_ssh_keys --add --name $KeyName --public-key-path $publicKeyPath"
    return
  }

  $localPublicKey = Get-LocalPublicKey -path $publicKeyPath
  if (-not $localPublicKey) {
    throw "Local public key missing at $publicKeyPath"
  }
  $localPublicKey = $localPublicKey.Trim()

  $remoteMatches = @()
  $remoteHasMatch = $false
  $remoteNeedsRegister = $true

  if ($RecreateRemote) {
    Write-Step 'RecreateRemote: deleting existing DigitalOcean SSH key(s)'
    $remoteMatches = Get-DoKeysByName -name $KeyName
    foreach ($match in $remoteMatches) {
      Remove-DoKey -keyId $match.id -fingerprint $match.fingerprint
    }
  } else {
    Write-Step 'Checking DigitalOcean SSH key matches local key'
    $remoteMatches = Get-DoKeysByName -name $KeyName
    if ($null -eq $remoteMatches) {
      $remoteMatches = @()
    } else {
      $remoteMatches = @($remoteMatches)
    }
    if ($remoteMatches.Count -eq 1 -and $remoteMatches[0] -is [System.Array]) {
      $remoteMatches = $remoteMatches[0]
    }
    Write-Info "Remote key matches found: $($remoteMatches.Count)"
    foreach ($match in $remoteMatches) {
      $remoteKey = $match.public_key
      if ($remoteKey) { $remoteKey = $remoteKey.Trim() }
      if ($remoteKey -eq $localPublicKey) {
        $remoteHasMatch = $true
        break
      }
    }
    if ($remoteHasMatch) {
      Write-Info 'DigitalOcean SSH key already matches local public key.'
      $remoteNeedsRegister = $false
    } elseif ($remoteMatches.Count -gt 0) {
      Write-Step 'Remote key mismatch detected; deleting existing DigitalOcean SSH key(s)'
      foreach ($match in $remoteMatches) {
        Remove-DoKey -keyId $match.id -fingerprint $match.fingerprint
      }
    }
  }

  if (-not $remoteNeedsRegister) {
    Write-Host 'OK: SSH key already in sync.' -ForegroundColor Green
    return
  }

  Write-Step 'Registering SSH key with DigitalOcean'
  $addArgs = @(
    '-m', 'digital_ocean.DO_ssh_keys',
    '--add',
    '--name', $KeyName,
    '--public-key-path', $publicKeyPath,
    '--json'
  )

  $tmpDoStdout = Join-Path $env:TEMP "do-ssh-keys-out-$PID.txt"
  $tmpDoStderr = Join-Path $env:TEMP "do-ssh-keys-err-$PID.txt"
  $doArgLine = $addArgs -join ' '
  $doProc = Start-Process -FilePath $PythonExe -ArgumentList $doArgLine -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmpDoStdout -RedirectStandardError $tmpDoStderr
  if (Test-Path $tmpDoStdout) { $doOutput += Get-Content -Path $tmpDoStdout -ErrorAction SilentlyContinue }
  if (Test-Path $tmpDoStderr) { $doOutput += Get-Content -Path $tmpDoStderr -ErrorAction SilentlyContinue }
  if ($doOutput) {
    $doOutput | ForEach-Object { Write-Host "[DO] $_" }
  }
  if ($doProc.ExitCode -ne 0) {
    throw "DO_ssh_keys failed with exit code $($doProc.ExitCode)"
  }

  try {
    $jsonText = ($doOutput -join "`n")
    $start = $jsonText.IndexOf('{')
    $end = $jsonText.LastIndexOf('}')
    if ($start -ge 0 -and $end -gt $start) {
      $jsonPayload = $jsonText.Substring($start, $end - $start + 1)
      $resp = $jsonPayload | ConvertFrom-Json -ErrorAction Stop
      if ($resp.ssh_key) {
        $createdKeyId = $resp.ssh_key.id
        $createdFingerprint = $resp.ssh_key.fingerprint
        $createdRemote = -not ($resp.existing -eq $true)
      }
    }
  } catch {
    Write-Info 'Could not parse DO_ssh_keys JSON output for cleanup.'
  }

  Write-Host 'OK: SSH key registered.' -ForegroundColor Green
} catch {
  $err = $_
  if ($createdRemote -and ($createdKeyId -or $createdFingerprint)) {
    Write-Step 'Cleanup: deleting DigitalOcean SSH key'
    $delArgs = @(
      '-m', 'digital_ocean.DO_ssh_keys',
      '--delete',
      '--yes',
      '--json'
    )
    if ($createdKeyId) {
      $delArgs += @('--id', $createdKeyId)
    } else {
      $delArgs += @('--fingerprint', $createdFingerprint)
    }
    & $PythonExe @delArgs | ForEach-Object { Write-Host "[DO] $_" }
  }
  if ($createdLocal) {
    Write-Step 'Cleanup: deleting local key files'
    if (Test-Path $privateKeyPath) { Remove-Item -Force $privateKeyPath }
    if (Test-Path $publicKeyPath) { Remove-Item -Force $publicKeyPath }
  }
  throw $err
} finally {
  if ($DryRun -and $createdLocal) {
    Write-Step 'Dry-run cleanup: deleting local key files'
    if (Test-Path $privateKeyPath) { Remove-Item -Force $privateKeyPath }
    if (Test-Path $publicKeyPath) { Remove-Item -Force $publicKeyPath }
    Write-Host 'OK: Dry-run complete (local artifacts cleaned up).' -ForegroundColor Green
  }
}

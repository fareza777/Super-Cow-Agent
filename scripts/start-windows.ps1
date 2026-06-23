# Start Cow Agent on Windows (stable background via cmd start)
$Root = Split-Path $PSScriptRoot -Parent
$VenvPython = Join-Path $Root ".venv\Scripts\python.exe"
$PyvenvCfg = Join-Path $Root ".venv\pyvenv.cfg"
$PidFile = Join-Path $Root ".cow.pid"
$LockFile = Join-Path $Root ".cow.starting.lock"
$ServiceLog = Join-Path $Root "service.log"

function Get-CowPython {
    if (Test-Path $PyvenvCfg) {
        $executable = Get-Content $PyvenvCfg | Where-Object { $_ -match '^\s*executable\s*=\s*(.+)$' } | ForEach-Object {
            $matches[1].Trim()
        } | Select-Object -First 1
        if ($executable -and (Test-Path $executable)) { return $executable }
    }
    if (Test-Path $VenvPython) { return $VenvPython }
    return $null
}

$Python = if (Test-Path $VenvPython) { $VenvPython } else { Get-CowPython }

if (-not (Test-Path $Python)) {
    Write-Error "Python venv not found: $Python"
    exit 1
}

function Test-CowHealthy {
    try {
        $health = Invoke-WebRequest -Uri "http://127.0.0.1:9899" -UseBasicParsing -TimeoutSec 4
        return ($health.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Get-ListenerPidForPort {
    param([int]$TargetPort = 9899)
    $matches = netstat -ano -p tcp | Select-String ":$TargetPort\s"
    foreach ($line in $matches) {
        $parts = ($line -replace '\s+', ' ').ToString().Trim().Split(' ')
        if ($parts.Length -ge 5 -and $parts[3] -eq "LISTENING") {
            return [int]$parts[4]
        }
    }
    return $null
}

if (Test-CowHealthy) {
    $listenerPid = Get-ListenerPidForPort
    if ($listenerPid) { Set-Content -Path $PidFile -Value $listenerPid -NoNewline }
    Write-Host "CowAgent already running (HTTP 200 on :9899)"
    exit 0
}

if (Test-Path $LockFile) {
    $lockAge = (Get-Date) - (Get-Item $LockFile).LastWriteTime
    if ($lockAge.TotalMinutes -lt 10) {
        Write-Host "CowAgent start already in progress (lock file, age $([int]$lockAge.TotalSeconds)s)"
        exit 0
    }
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}

if (Test-Path $PidFile) {
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

Set-Content -Path $LockFile -Value (Get-Date -Format "o") -Encoding UTF8

try {
    $escapedRoot = $Root.Replace("'", "''")
    $escapedPython = $Python.Replace("'", "''")
    $command = "Set-Location -LiteralPath '$escapedRoot'; & '$escapedPython' app.py"
    $launch = Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-WindowStyle", "Hidden", "-Command", $command) `
        -WorkingDirectory $Root `
        -WindowStyle Hidden `
        -PassThru

    Add-Content -Path $ServiceLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Launch via hidden PowerShell PID $($launch.Id)" -Encoding UTF8

    $healthy = $false
    for ($i = 1; $i -le 18; $i++) {
        Start-Sleep -Seconds 5
        if (Test-CowHealthy) {
            $healthy = $true
            break
        }
    }

    if ($healthy) {
        $cowPid = Get-ListenerPidForPort
        if ($cowPid) { Set-Content -Path $PidFile -Value $cowPid -NoNewline }
        Write-Host "CowAgent started (PID: $cowPid)"
        Write-Host "Web console: http://localhost:9899/chat"
        exit 0
    }

    Write-Host "CowAgent start requested but health check failed. See $ServiceLog"
    exit 1
} finally {
    if (Test-Path $LockFile) {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    }
}
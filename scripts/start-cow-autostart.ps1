# Safe Cow autostart after Windows logon. Runs once, no loop.
$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent
$StartScript = Join-Path $PSScriptRoot "start-windows.ps1"
$LogFile = Join-Path $Root "autostart.log"
$HealthUrl = "http://127.0.0.1:9899"
$StartupDelaySec = 60

function Write-AutoLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Test-CowHealthy {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 4
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

try {
    if (-not (Test-Path $StartScript)) {
        Write-AutoLog "ERROR: start script missing: $StartScript"
        exit 1
    }

    Write-AutoLog "Waiting ${StartupDelaySec}s after logon"
    Start-Sleep -Seconds $StartupDelaySec

    if (Test-CowHealthy) {
        Write-AutoLog "SKIP: Cow Agent already healthy at $HealthUrl"
        exit 0
    }

    Write-AutoLog "Invoking safe start script"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StartScript | Out-File -FilePath $LogFile -Append -Encoding UTF8

    if (Test-CowHealthy) {
        Write-AutoLog "SUCCESS: Cow Agent is up at $HealthUrl"
        exit 0
    }

    Write-AutoLog "WARN: Start finished but health check failed"
    exit 1
} catch {
    Write-AutoLog "ERROR: $($_.Exception.Message)"
    exit 1
}
# Cow Agent watchdog: restart only when HTTP health fails. No loop while healthy.
$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent
$StartScript = Join-Path $PSScriptRoot "start-windows.ps1"
$LogFile = Join-Path $Root "watchdog.log"
$HealthUrl = "http://127.0.0.1:9899"

function Write-WatchLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Test-CowHealthy {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

try {
    if (Test-CowHealthy) {
        exit 0
    }

    Write-WatchLog "Cow down at $HealthUrl - invoking safe start"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StartScript | Out-Null

    if (Test-CowHealthy) {
        Write-WatchLog "SUCCESS: Cow recovered"
        exit 0
    }

    Write-WatchLog "WARN: Start finished but health still failing"
    exit 1
} catch {
    Write-WatchLog "ERROR: $($_.Exception.Message)"
    exit 1
}
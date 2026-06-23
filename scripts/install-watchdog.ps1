# Register Cow watchdog task (every 10 min, start only if HTTP down).
$ErrorActionPreference = "Stop"

$TaskName = "CowAgent-Watchdog"
$ScriptPath = Join-Path $PSScriptRoot "watchdog-cow.ps1"
$UserName = $env:USERNAME

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Watchdog script not found: $ScriptPath"
    exit 1
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -RestartCount 0

$principal = New-ScheduledTaskPrincipal -UserId $UserName -LogonType Interactive -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Revive Cow Agent if http://127.0.0.1:9899 is down (every 10 min)" `
    -Force | Out-Null

Write-Host "Installed scheduled task: $TaskName"
Write-Host "Trigger: every 10 minutes (starts 2 min after install)"
Write-Host "Policy: IgnoreNew - only starts when HTTP health fails"
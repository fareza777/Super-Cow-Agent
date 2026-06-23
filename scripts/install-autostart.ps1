# Register a single logon task for Cow Agent autostart.
# Re-run safely: updates existing task instead of creating duplicates.

$ErrorActionPreference = "Stop"

$TaskName = "CowAgent-AutoStart"
$ScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\start-cow-autostart.ps1"
$UserName = $env:USERNAME

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Autostart script not found: $ScriptPath"
    exit 1
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $UserName
$trigger.Delay = "PT60S"

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RestartCount 0

$principal = New-ScheduledTaskPrincipal -UserId $UserName -LogonType Interactive -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Start Cow Agent once after user logon if not already running" `
    -Force | Out-Null

Write-Host "Installed scheduled task: $TaskName"
Write-Host "Trigger: At logon for $UserName (+60s delay)"
Write-Host "Policy: IgnoreNew (no double-start while task is running)"
Write-Host "Script: $ScriptPath"
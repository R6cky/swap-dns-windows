# =========================
# Variables
# =========================
$taskName = "swap-dns"
$scriptPath = "C:\system_64\swapdns.ps1"

# =========================
# Action: run PowerShell
# =========================
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

# =========================
# Trigger: at startup
# =========================
$trigger = New-ScheduledTaskTrigger -AtStartup

# =========================
# Principal: SYSTEM (admin)
# =========================
$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -RunLevel Highest

# =========================
# Settings
# =========================
$settings = New-ScheduledTaskSettingsSet `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)

# =========================
# Register task
# =========================
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Force

Write-Host "Task '$taskName' created successfully"

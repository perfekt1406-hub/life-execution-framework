#Requires -Version 5.1
<#
.SYNOPSIS
  Installs the Life Framework daily autostart on Windows via Task Scheduler.
.DESCRIPTION
  Creates a PowerShell gate script that opens life-framework.html once per
  logical day (day boundary = 03:30 local), and registers a Task Scheduler
  task that runs it at every user logon. Safe to re-run (idempotent).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Resolve paths ───────────────────────────────────────────────────────────
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Target     = Join-Path $ScriptDir "life-framework.html"
$GateDir    = Join-Path $env:USERPROFILE ".local\bin"
$GateScript = Join-Path $GateDir "life-framework-daily.ps1"
$TaskName   = "LifeFrameworkDaily"

if (-not (Test-Path $Target)) {
    Write-Error "life-framework.html not found next to this script ($ScriptDir)"
    exit 1
}

# ── Write gate script ──────────────────────────────────────────────────────
if (-not (Test-Path $GateDir)) { New-Item -ItemType Directory -Path $GateDir -Force | Out-Null }

$GateContent = @"
`$StampFile     = Join-Path `$env:USERPROFILE ".local\state\life-framework-last-open"
`$Target        = "$Target"
`$DayStartHour  = 3
`$DayStartMin   = 30

`$StampDir = Split-Path -Parent `$StampFile
if (-not (Test-Path `$StampDir)) { New-Item -ItemType Directory -Path `$StampDir -Force | Out-Null }

`$now = Get-Date
`$today = `$now.ToString("yyyy-MM-dd")

if (`$now.Hour -lt `$DayStartHour -or (`$now.Hour -eq `$DayStartHour -and `$now.Minute -lt `$DayStartMin)) {
    `$logicalDate = `$now.AddDays(-1).ToString("yyyy-MM-dd")
} else {
    `$logicalDate = `$today
}

`$lastOpen = if (Test-Path `$StampFile) { Get-Content `$StampFile -Raw | ForEach-Object { `$_.Trim() } } else { "" }

if (`$lastOpen -eq `$logicalDate) { exit 0 }

Set-Content -Path `$StampFile -Value `$logicalDate -NoNewline

Start-Sleep -Seconds 3
Start-Process `$Target
"@

Set-Content -Path $GateScript -Value $GateContent -Encoding UTF8
Write-Host "Wrote gate script: $GateScript"

# ── Register Task Scheduler task ───────────────────────────────────────────
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed existing task: $TaskName"
}

$action  = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$GateScript`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Open Life Framework on first login of the day" | Out-Null

Write-Host "Registered Task Scheduler task: $TaskName"

# ── Done ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Done! Life Framework will open in your default browser on each Windows login (once per day)."
Write-Host ""
Write-Host "  Stamp file: $env:USERPROFILE\.local\state\life-framework-last-open"
Write-Host "  To test now: powershell -File `"$GateScript`""
Write-Host "  To force re-open tomorrow: Remove-Item `"$env:USERPROFILE\.local\state\life-framework-last-open`""

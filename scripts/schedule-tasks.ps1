# Registers all scheduled tasks (run as Administrator). Edit paths if needed.
$S = "C:\ops\scripts"   # where you copy these scripts on the server
$run = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File"
schtasks /Create /F /RU SYSTEM /SC DAILY   /ST 02:00 /TN "Elearning\Backup-Full" /TR "$run $S\backup.ps1 -Type Full"
schtasks /Create /F /RU SYSTEM /SC HOURLY  /MO 6     /TN "Elearning\Backup-Diff" /TR "$run $S\backup.ps1 -Type Diff"
schtasks /Create /F /RU SYSTEM /SC MINUTE  /MO 15    /TN "Elearning\Backup-Log"  /TR "$run $S\backup.ps1 -Type Log"
schtasks /Create /F /RU SYSTEM /SC MINUTE  /MO 1     /TN "Elearning\HealthMonitor" /TR "$run $S\health-monitor.ps1"
Write-Host "Tasks registered. Weekly restore test: run restore-test.ps1 on the TEST server."

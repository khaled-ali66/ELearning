<#  One-time IIS setup. Run as Administrator.
    .\01-setup-iis.ps1 -Domain elearning.example.com -DbConnection "Server=...;Database=ElearningDB;User Id=ElearningApp;Password=...;Encrypt=True;TrustServerCertificate=False"
#>
param(
  [Parameter(Mandatory)][string]$Domain,
  [Parameter(Mandatory)][string]$DbConnection,
  [string]$Root = "C:\inetpub\Elearning",
  [string]$Pool = "ElearningPool",
  [string]$Site = "Elearning"
)
$ErrorActionPreference = "Stop"
Install-WindowsFeature Web-Server, Web-Asp-Net45, Web-Http-Redirect, Web-Http-Logging, Web-Stat-Compression, Web-Filtering, Web-Mgmt-Console -IncludeManagementTools | Out-Null
Import-Module WebAdministration
# NOTE: install the ".NET 8 Hosting Bundle" and the IIS "URL Rewrite" module manually before this step.

# Folders: blue/green slots + logs + uploads
foreach ($d in "blue","green","logs","uploads") { New-Item -ItemType Directory -Force -Path "$Root\$d" | Out-Null }
"blue" | Set-Content "$Root\current.txt"

# Application Pool
if (-not (Test-Path "IIS:\AppPools\$Pool")) { New-WebAppPool -Name $Pool | Out-Null }
$p = "IIS:\AppPools\$Pool"
Set-ItemProperty $p managedRuntimeVersion ""                           # No Managed Code
Set-ItemProperty $p processModel.identityType ApplicationPoolIdentity
Set-ItemProperty $p processModel.idleTimeout "00:00:00"                # never idle out
Set-ItemProperty $p startMode AlwaysRunning
Set-ItemProperty $p recycling.periodicRestart.time "1.05:00:00"        # 1740 min
Set-ItemProperty $p recycling.periodicRestart.privateMemory 1048576    # 1 GB (KB)
Set-ItemProperty $p failure.rapidFailProtection $true
Set-ItemProperty $p failure.rapidFailProtectionMaxCrashes 5

# Env vars for the app (secrets never stored in the repo)
$appcmd = "$env:windir\system32\inetsrv\appcmd.exe"
& $appcmd set config -section:system.applicationHost/applicationPools "/+[name='$Pool'].environmentVariables.[name='DB_CONNECTION',value='$DbConnection']" /commit:apphost
& $appcmd set config -section:system.applicationHost/applicationPools "/+[name='$Pool'].environmentVariables.[name='ASPNETCORE_ENVIRONMENT',value='Production']" /commit:apphost

# Production site (port 80 + 443 bindings; cert is bound by win-acme in step 02)
if (-not (Test-Path "IIS:\Sites\$Site")) {
  New-Website -Name $Site -PhysicalPath "$Root\blue" -ApplicationPool $Pool -HostHeader $Domain -Port 80 | Out-Null
}
# Staging site on localhost:8081 (used by deploy.ps1 to smoke-test the new slot)
if (-not (Test-Path "IIS:\Sites\${Site}Staging")) {
  New-Website -Name "${Site}Staging" -PhysicalPath "$Root\green" -ApplicationPool $Pool -Port 8081 | Out-Null
}

# Minimum permissions
foreach ($slot in "blue","green") {
  icacls "$Root\$slot" /grant "IIS AppPool\${Pool}:(OI)(CI)(RX)" | Out-Null
}
icacls "$Root\logs"    /grant "IIS AppPool\${Pool}:(OI)(CI)(M)" | Out-Null
icacls "$Root\uploads" /grant "IIS AppPool\${Pool}:(OI)(CI)(M)" | Out-Null
icacls $Root /remove "Users" 2>$null | Out-Null
icacls $Root /remove "Everyone" 2>$null | Out-Null
# Uploads must never execute code
& $appcmd set config "$Site/uploads" -section:system.webServer/handlers /accessPolicy:Read /commit:apphost 2>$null

Write-Host "IIS ready. Next: scripts\02-setup-ssl.ps1"

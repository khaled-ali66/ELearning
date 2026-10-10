<#
 Blue/Green zero-downtime deploy with automatic rollback.
 .\deploy.ps1 -Version v1.0.1 -Artifact "\\build-server\artifacts\v1.0.1" -ProdUrl https://elearning.example.com
 Flow: copy to INACTIVE slot -> migrate -> smoke test on staging site (:8081) -> switch prod path -> health check -> rollback on failure.
 Production keeps serving the old slot until the new one is proven healthy.
#>
param(
  [Parameter(Mandatory)][string]$Version,
  [Parameter(Mandatory)][string]$Artifact,
  [Parameter(Mandatory)][string]$ProdUrl,
  [string]$Root = "C:\inetpub\Elearning",
  [string]$Site = "Elearning",
  [string]$Pool = "ElearningPool",
  [string]$ConfigDir = "C:\Configs",
  [string]$StagingUrl = "http://localhost:8081",
  [string]$MigrationBundle = ""     # optional: path to efbundle.exe produced in CI
)
$ErrorActionPreference = "Stop"
Import-Module WebAdministration
$sw = [Diagnostics.Stopwatch]::StartNew()
$logFile = "$Root\logs\deploy-$(Get-Date -Format yyyyMMdd).log"
function Log($m) { $l="$(Get-Date -Format 'HH:mm:ss') $m"; Write-Host $l; Add-Content $logFile $l }

function Test-Health($url, $tries = 6) {
  for ($i=1; $i -le $tries; $i++) {
    try { if ((Invoke-WebRequest "$url/health/ready" -UseBasicParsing -TimeoutSec 15).StatusCode -eq 200) { return $true } } catch {}
    Start-Sleep 5
  }
  return $false
}

$active   = (Get-Content "$Root\current.txt").Trim()
$inactive = if ($active -eq "blue") { "green" } else { "blue" }
$newPath  = "$Root\$inactive"; $oldPath = "$Root\$active"
Log "Deploying $Version | active=$active -> new slot=$inactive"

try {
  # 1. Copy artifact into the inactive slot (production untouched)
  robocopy $Artifact $newPath /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
  Copy-Item "$ConfigDir\appsettings.Production.json" $newPath -Force
  icacls $newPath /grant "IIS AppPool\${Pool}:(OI)(CI)(RX)" | Out-Null
  New-Item -ItemType Directory -Force "$newPath\logs" | Out-Null

  # 2. DB migrations (must be backward compatible with the currently running version)
  if ($MigrationBundle) {
    Log "Running migrations"
    & $MigrationBundle --connection $env:DB_CONNECTION
    if ($LASTEXITCODE -ne 0) { throw "Migrations failed" }
  }

  # 3. Smoke test the new slot on the staging site
  Set-ItemProperty "IIS:\Sites\${Site}Staging" physicalPath $newPath
  if (-not (Test-Health $StagingUrl)) { throw "Smoke test failed on new slot" }
  Log "Smoke test passed"

  # 4. Switch production to the new slot
  Set-ItemProperty "IIS:\Sites\$Site" physicalPath $newPath
  if (-not (Test-Health $ProdUrl)) { throw "Production health check failed after switch" }

  Set-Content "$Root\current.txt" $inactive
  Log "SUCCESS: $Version live on $inactive in $([int]$sw.Elapsed.TotalSeconds)s"
  Add-Content "$Root\RELEASES.md" "- $(Get-Date -Format 'yyyy-MM-dd HH:mm') | $Version | SUCCESS | $([int]$sw.Elapsed.TotalSeconds)s | deployed by $env:USERNAME"
  if ($sw.Elapsed.TotalMinutes -gt 5) { Log "WARNING: deployment exceeded the 5-minute target" }
}
catch {
  Log "FAILED: $_ -> ROLLING BACK to $active"
  Set-ItemProperty "IIS:\Sites\$Site" physicalPath $oldPath      # instant: old slot is still intact
  Add-Content "$Root\RELEASES.md" "- $(Get-Date -Format 'yyyy-MM-dd HH:mm') | $Version | ROLLED BACK | $_"
  if (Test-Health $ProdUrl 3) { Log "Rollback OK, site healthy on $active" } else { Log "CRITICAL: site unhealthy after rollback" }
  exit 1
}

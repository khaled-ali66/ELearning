<# Usage: .\backup.ps1 -Type Full|Diff|Log
   Writes to D:\Backups, verifies, cleans old files, syncs off-site, logs to D:\Backups\backup.log #>
param([ValidateSet("Full","Diff","Log")][string]$Type = "Full",
      [string]$Db = "ElearningDB", [string]$Dir = "D:\Backups",
      [string]$S3Bucket = "", [string]$AzureUrl = "")
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$log = "$Dir\backup.log"
function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Type] $m" | Tee-Object -FilePath $log -Append }
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
try {
  switch ($Type) {
    "Full" { $file="$Dir\${Db}_Full_$ts.bak"; $sql="BACKUP DATABASE [$Db] TO DISK='$file' WITH COMPRESSION, CHECKSUM, INIT, STATS=10"; $keep=30 }
    "Diff" { $file="$Dir\${Db}_Diff_$ts.bak"; $sql="BACKUP DATABASE [$Db] TO DISK='$file' WITH DIFFERENTIAL, COMPRESSION, CHECKSUM, STATS=10"; $keep=7 }
    "Log"  { $file="$Dir\${Db}_Log_$ts.trn";  $sql="BACKUP LOG [$Db] TO DISK='$file' WITH COMPRESSION, CHECKSUM, STATS=10"; $keep=3 }
  }
  sqlcmd -S localhost -E -b -Q $sql | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "BACKUP failed" }
  sqlcmd -S localhost -E -b -Q "RESTORE VERIFYONLY FROM DISK='$file' WITH CHECKSUM" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "VERIFYONLY failed" }
  Log "OK $file ($([math]::Round((Get-Item $file).Length/1MB,1)) MB) verified"

  # retention
  Get-ChildItem $Dir -Filter "${Db}_${Type}_*" | Where-Object LastWriteTime -lt (Get-Date).AddDays(-$keep) | Remove-Item -Force

  # off-site (only if configured)
  if ($S3Bucket)  { aws s3 sync $Dir "s3://$S3Bucket/" --storage-class STANDARD_IA --exclude "*.log"; Log "synced to S3" }
  if ($AzureUrl)  { azcopy sync $Dir $AzureUrl --recursive; Log "synced to Azure Blob" }
} catch {
  Log "FAILED: $_"
  exit 1
}

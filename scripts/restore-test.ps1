<# Weekly restore test on a TEST server. Restores latest full backup to a scratch DB, runs CHECKDB, drops it.
   Assumes logical file names ElearningDB / ElearningDB_log (check: RESTORE FILELISTONLY FROM DISK='...'). #>
param([string]$Dir = "D:\Backups", [string]$Db = "ElearningDB", [string]$DataDir = "D:\SQLData")
$ErrorActionPreference = "Stop"
$bak = Get-ChildItem $Dir -Filter "${Db}_Full_*.bak" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $bak) { throw "No full backup found" }
$test = "${Db}_RestoreTest"
$sql = @"
RESTORE DATABASE [$test] FROM DISK='$($bak.FullName)'
WITH MOVE '$Db' TO '$DataDir\$test.mdf', MOVE '${Db}_log' TO '$DataDir\$test.ldf', REPLACE, STATS=10;
DBCC CHECKDB([$test]) WITH NO_INFOMSGS;
SELECT COUNT(*) AS TableCount FROM [$test].sys.tables;
DROP DATABASE [$test];
"@
sqlcmd -S localhost -E -b -Q $sql
$res = if ($LASTEXITCODE -eq 0) { "SUCCESS" } else { "FAILED" }
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [RestoreTest] $res using $($bak.Name)" | Tee-Object -FilePath "$Dir\backup.log" -Append
if ($LASTEXITCODE -ne 0) { exit 1 }

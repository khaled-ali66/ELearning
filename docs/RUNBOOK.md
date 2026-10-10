# Elearning Production Runbook

## 1. Architecture
Users → DNS (domain) → IIS (HTTPS, App Pool `ElearningPool`) → ASP.NET Core 8 → SQL Server (`ElearningDB`)
Cross-cutting: Serilog (File + SQL + Seq), Application Insights, Health Checks, daily backups with off-site sync.

| Item | Value |
|---|---|
| Site / Pool | `Elearning` / `ElearningPool` |
| Slots | `C:\inetpub\Elearning\blue` and `\green` (active slot in `current.txt`) |
| Staging site | `http://localhost:8081` (smoke test of new slot) |
| Logs | `C:\inetpub\Elearning\logs`, Seq, SQL table `Logs` |
| Backups | `D:\Backups` + off-site (S3 / Azure Blob) |
| Health | `/health/live`, `/health/ready`, `/health` |

## 2. First-time setup (order)
1. Windows Server + install .NET 8 Hosting Bundle + IIS URL Rewrite.
2. SQL: `sqlcmd -S . -E -i sql\01-setup-production.sql -v AppPassword="..."`; take first full backup.
3. `scripts\01-setup-iis.ps1 -Domain ... -DbConnection ...`
4. DNS A record → server IP; open ports 80/443.
5. `scripts\02-setup-ssl.ps1 -Domain ... -Email ...`; copy `appsettings.Production.json` to `C:\Configs\` (no secrets).
6. Copy scripts to `C:\ops\scripts`, run `schedule-tasks.ps1`.
7. `scripts\azure-alerts.ps1 ...`
8. Verify: SSLLabs grade A, `curl -I http://domain` = 301, `/health` = Healthy.

## 3. Deploy
```powershell
.\deploy.ps1 -Version v1.0.1 -Artifact "\\build-server\artifacts\v1.0.1" -ProdUrl https://elearning.example.com
```
Flow: copy to inactive slot → migrations → smoke test (:8081) → switch → health check → auto-rollback on failure.
Target: < 5 min, zero downtime. Result is appended to `RELEASES.md`.

## 4. Rollback (manual)
```powershell
$root="C:\inetpub\Elearning"; $cur=(gc $root\current.txt).Trim(); $prev= if($cur -eq "blue"){"green"}else{"blue"}
Set-ItemProperty IIS:\Sites\Elearning physicalPath "$root\$prev"; $prev | sc $root\current.txt
```
(Only valid if the previous slot still holds the previous version.) DB changes must be backward compatible, otherwise restore from backup.

## 5. Backups
| Type | Schedule | Retention |
|---|---|---|
| Full | daily 02:00 | 30 days |
| Differential | every 6 h | 7 days |
| Log | every 15 min | 3 days |
| Off-site sync | each run (if configured) | per bucket policy |
| Restore test | weekly on TEST server (`restore-test.ps1`) | — |

Check `D:\Backups\backup.log` daily. **Restore:** `RESTORE DATABASE` from latest full → latest diff `WITH NORECOVERY` → log backups → `RECOVERY`.

## 6. Incident checklist
1. Check `/health` and Application Insights (Failures, Performance).
2. Check Seq / `logs\elearning-*.log` using the user's Error ID.
3. Check App Pool state, CPU/RAM/disk, SQL connectivity.
4. If caused by last deploy → rollback (section 4).
5. Recycle pool: `Restart-WebAppPool ElearningPool`.
6. Write a post-mortem in `RELEASES.md`.

## 7. Security checklist
HTTPS + HSTS, secure headers, SQL login `ElearningApp` (no `sa`), secrets only in env vars, `Everyone/Users` removed from web root, uploads = Modify without Execute, certificate auto-renewal task exists.

## 8. Alerts
Response time > 2s · failed requests spike · CPU > 80% (5 min) · health check failed (2 consecutive minutes → webhook).

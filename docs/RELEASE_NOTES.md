# Release Notes
## v1.0.0 — Initial production release
- Deployed on IIS with a dedicated App Pool and blue/green slots
- HTTPS (Let's Encrypt), HSTS, secure headers, custom domain
- SQL Server production login (no `sa`), Full recovery model, scheduled backups
- Serilog (File + SQL + Seq), Application Insights, health checks, alerts
- `deploy.ps1` with automatic rollback; Runbook added
Deployment log: see `RELEASES.md` on the server (written automatically by `deploy.ps1`).

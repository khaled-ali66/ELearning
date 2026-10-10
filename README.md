# Elearning — Production Deployment Kit
Run order: `sql/01-setup-production.sql` → `scripts/01-setup-iis.ps1` → `scripts/02-setup-ssl.ps1` → `scripts/schedule-tasks.ps1` → `scripts/azure-alerts.ps1` → `scripts/deploy.ps1`.
Copy `src/*` into your ASP.NET Core project (merge `Program.cs.example` into your Program.cs). Full details: `docs/RUNBOOK.md`.

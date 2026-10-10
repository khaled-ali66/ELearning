<# Runs every minute (scheduled task). Alerts via webhook (Slack/Teams) after 2 consecutive failures. #>
param([string]$Url = "https://elearning.example.com/health/ready",
      [string]$Webhook = $env:ALERT_WEBHOOK_URL,
      [string]$State = "C:\ops\health.state")
$fails = if (Test-Path $State) { [int](Get-Content $State) } else { 0 }
try {
  $r = Invoke-WebRequest -Uri $Url -TimeoutSec 20 -UseBasicParsing
  if ($r.StatusCode -ne 200) { throw "status $($r.StatusCode)" }
  if ($fails -ge 2 -and $Webhook) { Invoke-RestMethod -Uri $Webhook -Method Post -ContentType 'application/json' -Body (@{text="✅ Elearning recovered"} | ConvertTo-Json) }
  Set-Content $State 0
} catch {
  $fails++; Set-Content $State $fails
  if ($fails -eq 2 -and $Webhook) {
    Invoke-RestMethod -Uri $Webhook -Method Post -ContentType 'application/json' -Body (@{text="🚨 Elearning health check FAILED: $_"} | ConvertTo-Json)
  }
}

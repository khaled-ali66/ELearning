<# Creates Application Insights alerts. Requires: az login. Fill the variables. #>
param([Parameter(Mandatory)][string]$ResourceGroup, [Parameter(Mandatory)][string]$AppInsights, [Parameter(Mandatory)][string]$Email)
$id = az monitor app-insights component show -g $ResourceGroup -a $AppInsights --query id -o tsv
az monitor action-group create -g $ResourceGroup -n elearning-ops --short-name elearn --action email admin $Email | Out-Null
$ag = az monitor action-group show -g $ResourceGroup -n elearning-ops --query id -o tsv

# Response time > 2s (avg over 5 min)
az monitor metrics alert create -g $ResourceGroup -n "resp-time-gt-2s" --scopes $id --condition "avg requests/duration > 2000" --window-size 5m --evaluation-frequency 1m --action $ag --severity 2
# Failed requests (error spike)
az monitor metrics alert create -g $ResourceGroup -n "failed-requests" --scopes $id --condition "count requests/failed > 10" --window-size 5m --evaluation-frequency 1m --action $ag --severity 1
# CPU > 80% for 5 min (needs performance counters enabled)
az monitor metrics alert create -g $ResourceGroup -n "cpu-gt-80" --scopes $id --condition "avg performanceCounters/processCpuPercentage > 80" --window-size 5m --evaluation-frequency 1m --action $ag --severity 2
Write-Host "Alerts created. Health-check failure alert: scripts\health-monitor.ps1 (every minute) -> webhook."

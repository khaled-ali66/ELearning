<# Free SSL via win-acme (Let's Encrypt). Download from https://www.win-acme.com and unzip to C:\tools\win-acme
   Prereq: DNS A record for the domain already points to this server's public IP, port 80 and 443 open. #>
param([Parameter(Mandatory)][string]$Domain, [Parameter(Mandatory)][string]$Email,
      [string]$Wacs = "C:\tools\win-acme\wacs.exe", [string]$SiteName = "Elearning")
$id = (Get-Website -Name $SiteName).Id
& $Wacs --target iis --siteid $id --host $Domain --installation iis --emailaddress $Email --accepttos --store certificatestore
# win-acme registers a daily scheduled task that renews automatically.
Write-Host "Verify:"
Write-Host "  curl -I http://$Domain   -> 301 to https"
Write-Host "  https://www.ssllabs.com/ssltest/analyze.html?d=$Domain  (target: A)"

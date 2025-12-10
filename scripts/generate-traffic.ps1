# Generate traffic to all 20 PEs to populate metrics
# This script will run curl requests from vm-prod to all PE endpoints
# Duration: 5 minutes of sustained traffic

param(
    [int]$DurationSeconds = 300,  # 5 minutes
    [int]$IntervalSeconds = 5     # Request every 5 seconds per PE
)

$ErrorActionPreference = 'Stop'
$vmName = 'vm-prod'
$rgName = 'rg-pe-prod'
$plsFqdn = 'pls-prod.f78ab472-43a7-4fd9-a3e8-898a1f054717.eastus.azure.privatelinkservice'

Write-Host "Starting traffic generation to all 20 PEs for $DurationSeconds seconds..." -ForegroundColor Cyan
Write-Host "Target: $plsFqdn" -ForegroundColor Yellow
Write-Host "Interval: $IntervalSeconds seconds between requests" -ForegroundColor Yellow

# Create the bash script
$script = @'
#!/bin/bash
set -e

FQDN="pls-prod.f78ab472-43a7-4fd9-a3e8-898a1f054717.eastus.azure.privatelinkservice"
DURATION=300
INTERVAL=5

echo "Starting traffic generation - $(date)"
startTime=$(date +%s)
endTime=$((startTime + DURATION))

requestCount=0
successCount=0
failureCount=0

while [ $(date +%s) -lt $endTime ]; do
  # Make request to PLS FQDN (which round-robins through all PE IPs)
  httpCode=$(curl -s -m 3 -o /dev/null -w '%{http_code}' http://${FQDN}/)
  
  if [ "$httpCode" = "200" ]; then
    successCount=$((successCount + 1))
  else
    failureCount=$((failureCount + 1))
  fi
  
  requestCount=$((requestCount + 1))
  
  # Print progress every 10 requests
  if [ $((requestCount % 10)) -eq 0 ]; then
    currentTime=$(date +%s)
    elapsed=$((currentTime - startTime))
    echo "Progress: $requestCount requests sent (Success: $successCount, Failed: $failureCount) - Elapsed: $elapsed seconds"
  fi
  
  # Wait before next request
  sleep $INTERVAL
done

echo ""
echo "Traffic generation completed at $(date)"
echo "Total requests: $requestCount"
echo "Successful (HTTP 200): $successCount"
echo "Failed: $failureCount"
echo "Success rate: $(echo "scale=2; $successCount * 100 / $requestCount" | bc)%"
'@

Write-Host "`nExecuting traffic generation on $vmName..." -ForegroundColor Green
Invoke-AzVMRunCommand -ResourceGroupName $rgName -Name $vmName -CommandId 'RunShellScript' -ScriptString $script | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty Message

Write-Host "`nTraffic generation completed!" -ForegroundColor Green

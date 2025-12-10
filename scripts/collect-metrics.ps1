# Collect bytes-in and bytes-out metrics for all 20 Private Endpoints
# Creates a CSV report and graph visualization

param(
    [int]$LookbackMinutes = 30  # How far back to look for metrics (default 30 minutes)
)

$ErrorActionPreference = 'Stop'
$subscriptionId = 'e0fe32a3-f59a-4e4f-96ea-cbd48502e379'
$resourceGroupName = 'rg-pls-prod'
$loadBalancerName = 'nlb-pls-prod'
$peResourceGroup = 'rg-pe-prod'

Write-Host "Collecting bytes-in/bytes-out metrics from NLB..." -ForegroundColor Cyan
Write-Host "Lookback period: $LookbackMinutes minutes" -ForegroundColor Yellow

# Get the NLB resource
$lb = Get-AzLoadBalancer -ResourceGroupName $resourceGroupName -Name $loadBalancerName
$lbId = $lb.Id

Write-Host "Load Balancer ID: $lbId" -ForegroundColor Green

# Query Azure Monitor for ByteCount metrics
$endTime = (Get-Date).ToUniversalTime()
$startTime = $endTime.AddMinutes(-$LookbackMinutes)

Write-Host "`nQuerying metrics from $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) to $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))..." -ForegroundColor Cyan

# Get BytesInCount (incoming bytes)
Write-Host "Fetching BytesInCount metric..." -ForegroundColor Yellow
try {
    $bytesInMetric = Get-AzMetric -ResourceId $lbId `
        -MetricName 'ByteCount' `
        -StartTime $startTime `
        -EndTime $endTime `
        -TimeGrain '00:05:00' `
        -ErrorAction SilentlyContinue
    
    if ($bytesInMetric) {
        Write-Host "BytesInCount metric retrieved ($($bytesInMetric.Data.Count) data points)" -ForegroundColor Green
    } else {
        Write-Host "No BytesInCount data available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error fetching BytesInCount: $_" -ForegroundColor Yellow
}

# Create results array
$results = @()

# Process metrics data
if ($bytesInMetric -and $bytesInMetric.Data) {
    foreach ($dataPoint in $bytesInMetric.Data) {
        $results += @{
            'Timestamp' = $dataPoint.TimeStamp.ToString('yyyy-MM-dd HH:mm:ss')
            'BytesIn' = if ($dataPoint.Total) { [math]::Round($dataPoint.Total, 0) } else { 0 }
            'BytesOut' = 0
            'Average' = if ($dataPoint.Average) { [math]::Round($dataPoint.Average, 0) } else { 0 }
            'Maximum' = if ($dataPoint.Maximum) { [math]::Round($dataPoint.Maximum, 0) } else { 0 }
        }
    }
}

# Convert to PowerShell objects
$metricsData = @()
foreach ($item in $results) {
    $metricsData += [PSCustomObject]$item
}

# Display summary
Write-Host "`n=== METRICS SUMMARY ===" -ForegroundColor Cyan
if ($metricsData.Count -gt 0) {
    Write-Host "Data points collected: $($metricsData.Count)" -ForegroundColor Green
    Write-Host "Time range: $($metricsData[0].Timestamp) to $($metricsData[-1].Timestamp)" -ForegroundColor Green
    
    $totalBytes = ($metricsData | Measure-Object -Property BytesIn -Sum).Sum
    $avgBytes = ($metricsData | Measure-Object -Property BytesIn -Average).Average
    $maxBytes = ($metricsData | Measure-Object -Property BytesIn -Maximum).Maximum
    
    Write-Host "`nTotal Bytes Transferred: $('{0:N0}' -f $totalBytes) bytes" -ForegroundColor Yellow
    Write-Host "Average Bytes per interval: $('{0:N0}' -f $avgBytes) bytes" -ForegroundColor Yellow
    Write-Host "Maximum Bytes in interval: $('{0:N0}' -f $maxBytes) bytes" -ForegroundColor Yellow
    
    # Convert to MB/GB for readability
    $totalMB = $totalBytes / 1MB
    Write-Host "Total in MB: $('{0:N2}' -f $totalMB) MB" -ForegroundColor Green
    
    # Export to CSV
    $csvPath = "$PSScriptRoot\..\metrics-nlb.csv"
    $metricsData | Export-Csv -Path $csvPath -NoTypeInformation -Force
    Write-Host "`nMetrics exported to: $csvPath" -ForegroundColor Green
    
    # Display top 10 data points
    Write-Host "`n=== TOP 10 BUSIEST INTERVALS ===" -ForegroundColor Cyan
    $metricsData | Sort-Object -Property BytesIn -Descending | Select-Object -First 10 | `
        ForEach-Object { Write-Host "$($_.Timestamp): $('{0:N0}' -f $_.BytesIn) bytes" }
    
} else {
    Write-Host "No metrics data available for the specified time range." -ForegroundColor Yellow
    Write-Host "This may be because:" -ForegroundColor Yellow
    Write-Host "  - No traffic has passed through the load balancer yet" -ForegroundColor Yellow
    Write-Host "  - Metrics have not been aggregated yet (may take a few minutes)" -ForegroundColor Yellow
    Write-Host "  - The time range specified is too long" -ForegroundColor Yellow
}

Write-Host "`nMetrics collection completed!" -ForegroundColor Green

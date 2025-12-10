<#
.SYNOPSIS
Discover all Private Endpoints connected to a specified Private Link Service (PLS)
across all subscriptions, collect their Bytes In/Out metrics from Azure Monitor,
and create an HTML dashboard to visualize the results.

.DESCRIPTION
Cross-subscription PLS PE metrics discovery and visualization tool.

FEATURES:
  * Discovers all Private Endpoints connected to a specified PLS across subscriptions
  * Collects PEBytesIn and PEBytesOut metrics from Azure Monitor
  * Supports multiple time-range input modes (absolute window, relative duration, lookback hours)
  * Metric aggregation: Sum, Average, Max, or Min over the time window
  * Generates interactive HTML dashboard with CSS-based bar charts (no JavaScript required)
  * Exports metrics to CSV for further analysis
  * All times in UTC; auto-validates user input with helpful examples

USAGE MODES:

  1. INTERACTIVE (Default) - No parameters needed:
     .\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod'
     Script will prompt for time range, aggregation method, etc.

  2. EXPLICIT TIME WINDOW (UTC):
     .\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' `
       -StartTime '2025-12-09 10:00:00' -EndTime '2025-12-09 12:00:00' `
       -AggregationMethod 'avg'

  3. RELATIVE DURATION (ends now, UTC):
     .\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -Duration '2h' -AggregationMethod 'sum'
     Supported durations: '2h', '5h', '1d', '30m', or just '24' (treated as hours)

  4. LOOKBACK HOURS (ends now, UTC):
     .\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -LookbackHours 24 -AggregationMethod 'max'

TIME INPUTS:
  * All times are UTC (no timezone conversion required)
  * Format: 'yyyy-MM-dd HH:mm:ss' (e.g., '2025-12-09 14:30:00')
  * Auto-validation: Script shows examples and re-prompts on invalid input

AGGREGATION METHODS:
  * 'sum'  : Total bytes across the time window (default)
  * 'avg'  : Average bytes per 5-minute interval
  * 'max'  : Maximum bytes in any 5-minute interval
  * 'min'  : Minimum bytes in any 5-minute interval

OUTPUTS:
  * CSV file: <PlsName>-pe-metrics-<yyyyMMdd-HHmmss>.csv
  * HTML dashboard: <PlsName>-pe-metrics-dashboard-<yyyyMMdd-HHmmss>.html

.PARAMETER PlsName
The name of the Private Link Service (required or prompted).

.PARAMETER StartTime
Explicit UTC start time (format: 'yyyy-MM-dd HH:mm:ss'). If provided, -EndTime is also required.

.PARAMETER EndTime
Explicit UTC end time (format: 'yyyy-MM-dd HH:mm:ss'). Requires -StartTime.

.PARAMETER Duration
Relative duration ending now (e.g., '2h', '1d', '30m'). Overrides -LookbackHours.

.PARAMETER LookbackHours
Number of hours to look back from now (default: 1).

.PARAMETER AggregationMethod
How to aggregate metrics: 'sum', 'avg', 'max', 'min' (default: 'sum').

.EXAMPLE
# Interactive mode - you'll be prompted for all options
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod'

# Explicit time window with average aggregation
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' `
  -StartTime '2025-12-09 10:00:00' -EndTime '2025-12-09 12:00:00' `
  -AggregationMethod 'avg'

# Last 2 hours, sum aggregation
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -Duration '2h' -AggregationMethod 'sum'

# Last 24 hours, max aggregation
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -LookbackHours 24 -AggregationMethod 'max'

#>

param(
    [string]$PlsName,
    [datetime]$StartTime,
    [datetime]$EndTime,
    [string]$Duration,
    [int]$LookbackHours = 1,
    [ValidateSet('sum', 'avg', 'max', 'min')]
    [string]$AggregationMethod = 'sum'
)

$ErrorActionPreference = 'Stop'

if (-not $PlsName) {
    $PlsName = Read-Host "Enter the Private Link Service name (e.g., 'pls-prod')"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CROSS-SUBSCRIPTION PLS PE METRICS DISCOVERY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PLS Name: $PlsName" -ForegroundColor Yellow
Write-Host "Aggregation Method: $AggregationMethod" -ForegroundColor Yellow
Write-Host "`nAll times are in UTC. Examples:"
Write-Host "  Valid start time: '2025-12-09 10:00:00'" -ForegroundColor Gray
Write-Host "  Valid duration:   '2h', '1d', '30m'" -ForegroundColor Gray

$subscriptions = Get-AzSubscription -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Enabled' }
Write-Host "Found $($subscriptions.Count) enabled subscription(s)" -ForegroundColor Green

$discoveredPes = @()
$plsResourceId = $null
$plsResourceGroup = $null
$plsSubscriptionId = $null

foreach ($sub in $subscriptions) {
    Write-Host "`nSearching subscription: $($sub.Name) (ID: $($sub.Id))" -ForegroundColor Cyan
    $null = Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue
    
    if (-not $plsResourceId) {
        Write-Host "  Looking for PLS: $PlsName..." -ForegroundColor Gray
        $pls = Get-AzPrivateLinkService -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $PlsName }
        
        if ($pls) {
            $plsResourceId = $pls.Id
            $plsResourceGroup = $pls.ResourceGroupName
            $plsSubscriptionId = $sub.Id
            Write-Host "  Found PLS: $PlsName in RG: $plsResourceGroup" -ForegroundColor Green
        }
    }
    
    if ($plsResourceId) {
        Write-Host "  Searching for Private Endpoints connected to PLS in this subscription..." -ForegroundColor Gray
        
        try {
            $allPes = Get-AzPrivateEndpoint -ErrorAction SilentlyContinue
            
            foreach ($pe in $allPes) {
                if ($pe.PrivateLinkServiceConnections) {
                    foreach ($conn in $pe.PrivateLinkServiceConnections) {
                        if ($conn.PrivateLinkServiceId -eq $plsResourceId) {
                            Write-Host "    Found PE: $($pe.Name) in RG: $($pe.ResourceGroupName)" -ForegroundColor Green
                            $discoveredPes += [PSCustomObject]@{
                                'PE_Name' = $pe.Name
                                'PE_Id' = $pe.Id
                                'PE_ResourceGroup' = $pe.ResourceGroupName
                                'PE_SubscriptionId' = $sub.Id
                                'PE_SubscriptionName' = $sub.Name
                                'PE_IP' = $pe.NetworkInterfaces[0].IpConfigurations[0].PrivateIPAddress
                                'Status' = 'Discovered'
                                'Bytes_In' = 0
                                'Bytes_Out' = 0
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Host "    Warning: Could not query PEs in this subscription" -ForegroundColor Yellow
        }
    }
}

if (-not $plsResourceId) {
    Write-Host "`nERROR: Could not find PLS '$PlsName' in any accessible subscription." -ForegroundColor Red
    exit 1
}

if ($discoveredPes.Count -eq 0) {
    Write-Host "`nWARNING: No Private Endpoints found connected to PLS '$PlsName'." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DISCOVERED PRIVATE ENDPOINTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total PEs found: $($discoveredPes.Count)" -ForegroundColor Green
$discoveredPes | Select-Object PE_Name, PE_ResourceGroup, PE_SubscriptionName, PE_IP | Format-Table -AutoSize

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "QUERYING AZURE MONITOR METRICS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

function Parse-DurationString {
    param([string]$s)
    if (-not $s) { return $null }
    if ($s -match '^\s*(\d+)\s*([hHdDmM])\s*$') { $n = [int]$Matches[1]; $u = $Matches[2].ToLower() }
    elseif ($s -match '^\s*(\d+)\s*$') { $n = [int]$Matches[1]; $u = 'h' }
    else { return $null }
    switch ($u) {
        'h' { return New-TimeSpan -Hours $n }
        'd' { return New-TimeSpan -Days $n }
        'm' { return New-TimeSpan -Minutes $n }
    }
}

function Validate-UtcDateTime {
    param([string]$input, [string]$label)
    try {
        return [datetime]::Parse($input)
    } catch {
        Write-Host "`nInvalid $label format." -ForegroundColor Red
        Write-Host "Expected format (UTC): 'yyyy-MM-dd HH:mm:ss'" -ForegroundColor Yellow
        Write-Host "Example: '2025-12-09 14:30:00'" -ForegroundColor Yellow
        return $null
    }
}

# Determine time window: explicit StartTime/EndTime > Duration > LookbackHours (interactive fallback)
if ($StartTime -and $EndTime) {
    $startTime = $StartTime
    $endTime = $EndTime
    Write-Host "Using explicit time window (UTC): $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) to $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
} elseif ($Duration) {
    $ts = Parse-DurationString $Duration
    if (-not $ts) {
        Write-Host "`nInvalid -Duration format." -ForegroundColor Red
        Write-Host "Supported formats: '2h', '5h', '1d', '30m', or just '24'" -ForegroundColor Yellow
        exit 1
    }
    $endTime = (Get-Date).ToUniversalTime()
    $startTime = $endTime.Subtract($ts)
    Write-Host "Using duration (UTC): Last $Duration (ending now)" -ForegroundColor Green
} else {
    Write-Host "`nTime range selection:" -ForegroundColor Yellow
    Write-Host "  1 = Use LookbackHours (default: $LookbackHours h)" -ForegroundColor Cyan
    Write-Host "  2 = Enter Duration (e.g., '2h', '1d')" -ForegroundColor Cyan
    Write-Host "  3 = Enter Start/End times (UTC format: 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    
    $choice = Read-Host "Select option (1-3, or press Enter for 1)"
    if ($choice -eq "" -or $choice -eq '1') {
        $endTime = (Get-Date).ToUniversalTime()
        $startTime = $endTime.AddHours(-$LookbackHours)
    } elseif ($choice -eq '2') {
        while ($true) {
            $durInput = Read-Host "Enter duration (examples: 2h, 5h, 1d, 30m)"
            $ts = Parse-DurationString $durInput
            if ($ts) {
                $endTime = (Get-Date).ToUniversalTime()
                $startTime = $endTime.Subtract($ts)
                break
            } else {
                Write-Host "Invalid format. Try: 2h, 1d, 30m, or just 24" -ForegroundColor Yellow
            }
        }
    } elseif ($choice -eq '3') {
        while ($true) {
            $s = Read-Host "Enter Start Time (UTC): yyyy-MM-dd HH:mm:ss (e.g., 2025-12-09 10:00:00)"
            $startTime = Validate-UtcDateTime $s "Start Time"
            if ($startTime) { break }
        }
        while ($true) {
            $e = Read-Host "Enter End Time (UTC): yyyy-MM-dd HH:mm:ss (e.g., 2025-12-09 12:00:00)"
            $endTime = Validate-UtcDateTime $e "End Time"
            if ($endTime) { break }
        }
    } else {
        # default fallback
        $endTime = (Get-Date).ToUniversalTime()
        $startTime = $endTime.AddHours(-$LookbackHours)
    }
}

Write-Host "`nTime range (UTC): $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) to $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan

# Determine aggregation method
if (-not $AggregationMethod -or $AggregationMethod -eq 'sum') {
    Write-Host "`nAggregation Method selection:" -ForegroundColor Yellow
    Write-Host "  1 = Sum (default) - Total bytes across time window" -ForegroundColor Cyan
    Write-Host "  2 = Average - Mean bytes per 5-minute interval" -ForegroundColor Cyan
    Write-Host "  3 = Max - Highest bytes in any 5-minute interval" -ForegroundColor Cyan
    Write-Host "  4 = Min - Lowest bytes in any 5-minute interval" -ForegroundColor Cyan
    
    $aggChoice = Read-Host "Select aggregation (1-4, or press Enter for 1)"
    switch ($aggChoice) {
        '2' { $AggregationMethod = 'avg' }
        '3' { $AggregationMethod = 'max' }
        '4' { $AggregationMethod = 'min' }
        default { $AggregationMethod = 'sum' }
    }
}

Write-Host "Aggregation: $AggregationMethod" -ForegroundColor Cyan

foreach ($pe in $discoveredPes) {
    Write-Host "`nQuerying PE: $($pe.PE_Name) (Subscription: $($pe.PE_SubscriptionName))" -ForegroundColor Cyan
    
    $null = Set-AzContext -SubscriptionId $pe.PE_SubscriptionId -ErrorAction SilentlyContinue
    
    try {
        $bytesInMetric = Get-AzMetric -ResourceId $pe.PE_Id `
            -MetricName 'PEBytesIn' `
            -StartTime $startTime `
            -EndTime $endTime `
            -TimeGrain '00:05:00' `
            -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        
        if ($bytesInMetric -and $bytesInMetric.Data) {
            $values = @()
            foreach ($dp in $bytesInMetric.Data) {
                if ($dp.Total) { $values += $dp.Total }
            }
            if ($values.Count -gt 0) {
                $pe.Bytes_In = switch ($AggregationMethod) {
                    'sum' { [math]::Round(($values | Measure-Object -Sum).Sum, 0) }
                    'avg' { [math]::Round(($values | Measure-Object -Average).Average, 0) }
                    'max' { [math]::Round(($values | Measure-Object -Maximum).Maximum, 0) }
                    'min' { [math]::Round(($values | Measure-Object -Minimum).Minimum, 0) }
                    default { [math]::Round(($values | Measure-Object -Sum).Sum, 0) }
                }
            } else {
                $pe.Bytes_In = 0
            }
            Write-Host "  Bytes In ($AggregationMethod): $($pe.Bytes_In) bytes" -ForegroundColor Green
        } else {
            $pe.Bytes_In = 0
            Write-Host "  Bytes In: No data found" -ForegroundColor Yellow
        }
    } catch {
        $pe.Bytes_In = 0
        Write-Host "  Bytes In: Error querying metric" -ForegroundColor Yellow
    }
    
    try {
        $bytesOutMetric = Get-AzMetric -ResourceId $pe.PE_Id `
            -MetricName 'PEBytesOut' `
            -StartTime $startTime `
            -EndTime $endTime `
            -TimeGrain '00:05:00' `
            -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        
        if ($bytesOutMetric -and $bytesOutMetric.Data) {
            $values = @()
            foreach ($dp in $bytesOutMetric.Data) {
                if ($dp.Total) { $values += $dp.Total }
            }
            if ($values.Count -gt 0) {
                $pe.Bytes_Out = switch ($AggregationMethod) {
                    'sum' { [math]::Round(($values | Measure-Object -Sum).Sum, 0) }
                    'avg' { [math]::Round(($values | Measure-Object -Average).Average, 0) }
                    'max' { [math]::Round(($values | Measure-Object -Maximum).Maximum, 0) }
                    'min' { [math]::Round(($values | Measure-Object -Minimum).Minimum, 0) }
                    default { [math]::Round(($values | Measure-Object -Sum).Sum, 0) }
                }
            } else {
                $pe.Bytes_Out = 0
            }
            Write-Host "  Bytes Out ($AggregationMethod): $($pe.Bytes_Out) bytes" -ForegroundColor Green
        } else {
            $pe.Bytes_Out = 0
            Write-Host "  Bytes Out: No data found" -ForegroundColor Yellow
        }
    } catch {
        $pe.Bytes_Out = 0
        Write-Host "  Bytes Out: Error querying metric" -ForegroundColor Yellow
    }
    
    Start-Sleep -Milliseconds 500
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "METRICS SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$discoveredPes | Select-Object PE_Name, PE_SubscriptionName, @{N='Bytes In';E={$_.Bytes_In}}, @{N='Bytes Out';E={$_.Bytes_Out}}, @{N='Total';E={$_.Bytes_In + $_.Bytes_Out}} | Format-Table -AutoSize

$metricsPath = "$PSScriptRoot\..\${PlsName}-pe-metrics-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$discoveredPes | Export-Csv -Path $metricsPath -NoTypeInformation -Force
Write-Host "`nMetrics exported to: $metricsPath" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CREATING HTML DASHBOARD" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$htmlDashboardPath = "$PSScriptRoot\..\${PlsName}-pe-metrics-dashboard-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"

$htmlContent = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PLS PE Metrics Dashboard - ' + $PlsName + '</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; color: #333; }
        .container { max-width: 1400px; margin: 0 auto; }
        .header { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); margin-bottom: 30px; }
        .header h1 { color: #333; margin-bottom: 10px; font-size: 28px; }
        .header p { color: #666; margin: 5px 0; font-size: 14px; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(500px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .metric-card h3 { color: #333; margin-bottom: 15px; border-bottom: 2px solid #667eea; padding-bottom: 10px; font-size: 16px; }
        .metric-values { display: flex; justify-content: space-around; margin-bottom: 20px; flex-wrap: wrap; }
        .metric-value { text-align: center; flex: 1; min-width: 150px; }
        .metric-value .label { color: #666; font-size: 13px; margin-bottom: 5px; }
        .metric-value .value { font-size: 22px; font-weight: bold; color: #667eea; }
        .chart-bar { width: 100%; background: #e0e0e0; height: 24px; border-radius: 3px; overflow: hidden; margin: 8px 0; position: relative; }
        .chart-bar-fill { height: 100%; display: flex; align-items: center; justify-content: flex-end; padding-right: 5px; font-size: 12px; font-weight: bold; color: white; }
        .bar-in { background: linear-gradient(90deg, #667eea 0%, #5568d3 100%); }
        .bar-out { background: linear-gradient(90deg, #764ba2 0%, #634880 100%); }
        .summary-table { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow-x: auto; }
        .summary-table h2 { color: #333; margin-bottom: 20px; font-size: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th { background: #667eea; color: white; padding: 12px; text-align: left; font-weight: 600; font-size: 13px; }
        td { padding: 12px; border-bottom: 1px solid #eee; font-size: 13px; }
        tr:hover { background: #f5f5f5; }
        .footer { text-align: center; color: #999; margin-top: 30px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>PLS Private Endpoint Metrics Dashboard</h1>
            <p><strong>PLS Name:</strong> ' + $PlsName + '</p>
            <p><strong>Total Private Endpoints:</strong> ' + $discoveredPes.Count + '</p>
            <p><strong>Lookback Period:</strong> ' + $LookbackHours + ' hour(s)</p>
            <p><strong>Generated:</strong> ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '</p>
            <p><strong>Time Range:</strong> ' + $startTime.ToString('yyyy-MM-dd HH:mm:ss') + ' to ' + $endTime.ToString('yyyy-MM-dd HH:mm:ss') + '</p>
        </div>

        <div class="summary-table">
            <h2>PE Metrics Summary</h2>
            <table>
                <thead>
                    <tr>
                        <th>PE Name</th>
                        <th>Subscription</th>
                        <th>Resource Group</th>
                        <th>Bytes In</th>
                        <th>Bytes Out</th>
                        <th>Total Bytes</th>
                    </tr>
                </thead>
                <tbody>'

foreach ($pe in $discoveredPes | Sort-Object PE_Name) {
    $totalBytes = $pe.Bytes_In + $pe.Bytes_Out
    $bytesInFormatted = "{0:N0}" -f $pe.Bytes_In
    $bytesOutFormatted = "{0:N0}" -f $pe.Bytes_Out
    $totalBytesFormatted = "{0:N0}" -f $totalBytes
    
    $htmlContent += '
                    <tr>
                        <td><strong>' + $pe.PE_Name + '</strong></td>
                        <td>' + $pe.PE_SubscriptionName + '</td>
                        <td>' + $pe.PE_ResourceGroup + '</td>
                        <td>' + $bytesInFormatted + '</td>
                        <td>' + $bytesOutFormatted + '</td>
                        <td>' + $totalBytesFormatted + '</td>
                    </tr>'
}

$htmlContent += '
                </tbody>
            </table>
        </div>

        <div class="metrics-grid">'

foreach ($pe in $discoveredPes | Sort-Object PE_Name) {
    $totalBytes = $pe.Bytes_In + $pe.Bytes_Out
    $bytesInPercent = if ($totalBytes -gt 0) { [math]::Round(($pe.Bytes_In / $totalBytes) * 100, 1) } else { 0 }
    $bytesOutPercent = if ($totalBytes -gt 0) { [math]::Round(($pe.Bytes_Out / $totalBytes) * 100, 1) } else { 0 }
    $bytesInFormatted = "{0:N0}" -f $pe.Bytes_In
    $bytesOutFormatted = "{0:N0}" -f $pe.Bytes_Out
    
    $maxValue = [math]::Max($pe.Bytes_In, $pe.Bytes_Out)
    if ($maxValue -eq 0) { $maxValue = 1 }
    
    $inBarWidth = [math]::Round(($pe.Bytes_In / $maxValue) * 100, 1)
    $outBarWidth = [math]::Round(($pe.Bytes_Out / $maxValue) * 100, 1)
    
    $htmlContent += '
            <div class="metric-card">
                <h3>' + $pe.PE_Name + '</h3>
                <div class="metric-values">
                    <div class="metric-value">
                        <div class="label">Bytes In</div>
                        <div class="value">' + $bytesInFormatted + '</div>
                        <div class="label">(' + $bytesInPercent + '%)</div>
                    </div>
                    <div class="metric-value">
                        <div class="label">Bytes Out</div>
                        <div class="value">' + $bytesOutFormatted + '</div>
                        <div class="label">(' + $bytesOutPercent + '%)</div>
                    </div>
                </div>
                <div style="margin-top:20px;">
                    <div style="font-size:12px; color:#666; margin-bottom:5px;"><strong>Bytes In:</strong></div>
                    <div class="chart-bar">
                        <div class="chart-bar-fill bar-in" style="width:' + $inBarWidth + '%;">' + $bytesInPercent + '%</div>
                    </div>
                    <div style="font-size:12px; color:#666; margin-top:15px; margin-bottom:5px;"><strong>Bytes Out:</strong></div>
                    <div class="chart-bar">
                        <div class="chart-bar-fill bar-out" style="width:' + $outBarWidth + '%;">' + $bytesOutPercent + '%</div>
                    </div>
                </div>
            </div>'
}

$htmlContent += '
        </div>

        <div class="footer">
            <p>Dashboard created by: PLS PE Metrics Collector PowerShell Script</p>
            <p>Azure Subscription: ' + $plsSubscriptionId + ' | PLS Resource Group: ' + $plsResourceGroup + '</p>
        </div>
    </div>
</body>
</html>'

$htmlContent | Out-File -FilePath $htmlDashboardPath -Encoding UTF8 -Force
Write-Host "HTML Dashboard created: $htmlDashboardPath" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "COMPLETION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ PLS discovered: $PlsName" -ForegroundColor Green
Write-Host "✓ Private Endpoints found: $($discoveredPes.Count)" -ForegroundColor Green
Write-Host "✓ Metrics exported: $metricsPath" -ForegroundColor Green
Write-Host "✓ Dashboard created: $htmlDashboardPath" -ForegroundColor Green

Write-Host "`nTo view the dashboard:" -ForegroundColor Yellow
Write-Host "  Start-Process '$htmlDashboardPath'" -ForegroundColor Cyan

Write-Host "`nDone!" -ForegroundColor Green

# Create a visual graph of NLB metrics using ASCII and HTML output

param(
    [string]$CsvPath = './metrics-nlb.csv',
    [string]$OutputHtmlPath = './metrics-graph.html'
)

$ErrorActionPreference = 'Stop'

Write-Host "Creating metrics visualization..." -ForegroundColor Cyan

# Check if CSV file exists
if (-not (Test-Path $CsvPath)) {
    Write-Host "ERROR: CSV file not found at: $CsvPath" -ForegroundColor Red
    Write-Host "Please run collect-metrics.ps1 first to generate the CSV file." -ForegroundColor Yellow
    exit 1
}

# Import CSV data
Write-Host "Loading metrics from: $CsvPath" -ForegroundColor Green
$metricsData = Import-Csv -Path $CsvPath

if (-not $metricsData -or $metricsData.Count -eq 0) {
    Write-Host "ERROR: No data found in CSV file" -ForegroundColor Red
    exit 1
}

# Convert BytesIn to numbers (in case they're strings)
$metricsData | ForEach-Object { $_.BytesIn = [int64]$_.BytesIn }

# Calculate statistics
$totalBytes = ($metricsData | Measure-Object -Property BytesIn -Sum).Sum
$avgBytes = ($metricsData | Measure-Object -Property BytesIn -Average).Average
$maxBytes = ($metricsData | Measure-Object -Property BytesIn -Maximum).Maximum
$minBytes = ($metricsData | Measure-Object -Property BytesIn -Minimum).Minimum

Write-Host "`n=== DATA STATISTICS ===" -ForegroundColor Cyan
Write-Host "Total data points: $($metricsData.Count)" -ForegroundColor Green
Write-Host "Total bytes: $('{0:N0}' -f $totalBytes)" -ForegroundColor Yellow
Write-Host "Average bytes/interval: $('{0:N0}' -f $avgBytes)" -ForegroundColor Yellow
Write-Host "Maximum bytes/interval: $('{0:N0}' -f $maxBytes)" -ForegroundColor Yellow
Write-Host "Minimum bytes/interval: $('{0:N0}' -f $minBytes)" -ForegroundColor Yellow

# Create ASCII chart
Write-Host "`n=== ASCII CHART ===" -ForegroundColor Cyan
Write-Host "Bytes transferred per 5-minute interval (scale: 1 # = ~100KB)" -ForegroundColor Gray

$scale = $maxBytes / 50  # Fit into 50 characters width

foreach ($row in $metricsData) {
    $timestamp = $row.Timestamp
    $bytes = $row.BytesIn
    $barLength = [math]::Round($bytes / $scale)
    $bar = '#' * $barLength
    $mbValue = [math]::Round($bytes / 1MB, 2)
    Write-Host "$timestamp | $bar $('{0:N2}' -f $mbValue) MB"
}

# Create HTML visualization
Write-Host "`nGenerating HTML graph..." -ForegroundColor Green

$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Private Link Service Metrics</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3.9.1/dist/chart.min.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            margin-top: 0;
            border-bottom: 3px solid #0078d4;
            padding-bottom: 10px;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .stat-card h3 {
            margin: 0 0 10px 0;
            font-size: 0.9em;
            opacity: 0.9;
        }
        .stat-card .value {
            font-size: 1.8em;
            font-weight: bold;
        }
        .stat-card.total { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
        .stat-card.avg { background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); }
        .stat-card.max { background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%); }
        .chart-container {
            position: relative;
            height: 400px;
            margin: 30px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 30px;
        }
        th {
            background-color: #0078d4;
            color: white;
            padding: 12px;
            text-align: left;
            font-weight: 600;
        }
        td {
            padding: 10px 12px;
            border-bottom: 1px solid #eee;
        }
        tr:hover {
            background-color: #f0f0f0;
        }
        .timestamp {
            font-family: 'Courier New', monospace;
            color: #666;
        }
        .bytes {
            text-align: right;
            font-family: 'Courier New', monospace;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Private Link Service - Bytes In/Out Metrics</h1>
        
        <div class="stats-grid">
            <div class="stat-card total">
                <h3>Total Bytes Transferred</h3>
                <div class="value">$('{0:N0}' -f $totalBytes)</div>
                <div>$('{0:N2}' -f ($totalBytes / 1MB)) MB</div>
            </div>
            <div class="stat-card avg">
                <h3>Average Per Interval</h3>
                <div class="value">$('{0:N0}' -f $avgBytes)</div>
                <div>$('{0:N2}' -f ($avgBytes / 1MB)) MB</div>
            </div>
            <div class="stat-card max">
                <h3>Peak Interval</h3>
                <div class="value">$('{0:N0}' -f $maxBytes)</div>
                <div>$('{0:N2}' -f ($maxBytes / 1MB)) MB</div>
            </div>
        </div>

        <h2>Bytes Transferred Over Time</h2>
        <div class="chart-container">
            <canvas id="metricsChart"></canvas>
        </div>

        <h2>Detailed Data</h2>
        <table>
            <thead>
                <tr>
                    <th>Timestamp</th>
                    <th class="bytes">Bytes In</th>
                    <th class="bytes">MB</th>
                    <th class="bytes">Average</th>
                    <th class="bytes">Maximum</th>
                </tr>
            </thead>
            <tbody>
"@

# Add table rows
foreach ($row in $metricsData) {
    $mbValue = [math]::Round($row.BytesIn / 1MB, 2)
    $htmlContent += @"
                <tr>
                    <td class="timestamp">$($row.Timestamp)</td>
                    <td class="bytes">$('{0:N0}' -f $row.BytesIn)</td>
                    <td class="bytes">$mbValue</td>
                    <td class="bytes">$('{0:N0}' -f $row.Average)</td>
                    <td class="bytes">$('{0:N0}' -f $row.Maximum)</td>
                </tr>
"@
}

# Prepare data for Chart.js
$labels = ($metricsData | ForEach-Object { $_.Timestamp }) -join "','"
$values = ($metricsData | ForEach-Object { [int64]$_.BytesIn }) -join ','

$htmlContent += @"
            </tbody>
        </table>

        <div class="footer">
            <p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
            <p>Data source: NLB metrics from Azure Monitor</p>
        </div>
    </div>

    <script>
        const ctx = document.getElementById('metricsChart').getContext('2d');
        const chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: ['$labels'],
                datasets: [{
                    label: 'Bytes In (5-min intervals)',
                    data: [$values],
                    borderColor: '#0078d4',
                    backgroundColor: 'rgba(0, 120, 212, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 4,
                    pointBackgroundColor: '#0078d4',
                    pointBorderColor: '#fff',
                    pointBorderWidth: 2,
                    pointHoverRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: true,
                        position: 'top'
                    },
                    title: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Bytes'
                        },
                        ticks: {
                            callback: function(value) {
                                return (value / 1048576).toFixed(2) + ' MB';
                            }
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Time'
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
"@

# Write HTML to file
$htmlContent | Out-File -FilePath $OutputHtmlPath -Encoding UTF8 -Force
Write-Host "HTML graph created: $OutputHtmlPath" -ForegroundColor Green

# Open in browser (on Windows)
if ($PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.OS -like '*Windows*') {
    Start-Process $OutputHtmlPath
    Write-Host "Opening in default browser..." -ForegroundColor Green
}

Write-Host "`nVisualization complete!" -ForegroundColor Green
Write-Host "CSV: $CsvPath" -ForegroundColor Gray
Write-Host "HTML: $(Resolve-Path $OutputHtmlPath)" -ForegroundColor Gray

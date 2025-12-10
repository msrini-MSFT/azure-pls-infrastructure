# Create interactive HTML graph for per-PE metrics with filtering
param([string]$CsvPath = "$PSScriptRoot\..\pe-metrics-detailed.csv")

Write-Host "Creating interactive PE metrics graph..." -ForegroundColor Cyan

# Import CSV data
if (-not (Test-Path $CsvPath)) {
    Write-Host "Error: pe-metrics-detailed.csv not found. Run collect-pe-metrics.ps1 first." -ForegroundColor Red
    exit 1
}

$peData = Import-Csv -Path $CsvPath
Write-Host "Loaded metrics for $($peData.Count) PEs" -ForegroundColor Green

# Convert data to JSON
$peDataJson = @($peData) | ConvertTo-Json

# Create HTML with embedded data
$htmlPath = "$PSScriptRoot\..\pe-metrics-graph.html"

$htmlContent = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Private Endpoint Metrics - Interactive Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3.9.1/dist/chart.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 32px;
            margin-bottom: 10px;
        }
        
        .controls {
            background: #f8f9fa;
            padding: 20px;
            border-bottom: 1px solid #e0e0e0;
            display: flex;
            gap: 15px;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .control-group {
            display: flex;
            gap: 10px;
            align-items: center;
        }
        
        .control-group label {
            font-weight: 600;
            color: #333;
        }
        
        select {
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 14px;
            background: white;
            cursor: pointer;
        }
        
        button {
            padding: 8px 16px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 6px;
            font-weight: 600;
            cursor: pointer;
        }
        
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        
        .content {
            padding: 30px;
        }
        
        .chart-container {
            position: relative;
            height: 400px;
            margin-bottom: 40px;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 40px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
        }
        
        .stat-label {
            font-size: 12px;
            opacity: 0.9;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .stat-value {
            font-size: 24px;
            font-weight: bold;
            margin-top: 8px;
        }
        
        .table-container {
            overflow-x: auto;
            background: white;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }
        
        th {
            background: #f8f9fa;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            color: #333;
            border-bottom: 2px solid #667eea;
        }
        
        td {
            padding: 12px;
            border-bottom: 1px solid #e0e0e0;
        }
        
        tr:hover {
            background: #f8f9fa;
        }
        
        tr.highlight {
            background: #f0f4ff;
        }
        
        .pe-number {
            font-weight: 600;
            color: #667eea;
        }
        
        h2 {
            color: #333;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>PE Metrics Dashboard</h1>
            <p>Interactive visualization of metrics across all Private Endpoints</p>
        </div>
        
        <div class="controls">
            <div class="control-group">
                <label for="metricType">Metric:</label>
                <select id="metricType" onchange="updateChart()">
                    <option value="total">Total Bytes</option>
                    <option value="avg">Average Bytes</option>
                    <option value="max">Max Bytes</option>
                </select>
            </div>
            
            <div class="control-group">
                <label for="peFilter">Filter PE:</label>
                <select id="peFilter" onchange="updateChart()">
                    <option value="all">All PEs</option>
                </select>
            </div>
            
            <div class="control-group">
                <label for="sortBy">Sort By:</label>
                <select id="sortBy" onchange="updateChart()">
                    <option value="number">PE Number</option>
                    <option value="value">Metric Value</option>
                </select>
            </div>
            
            <button onclick="resetFilters()">Reset</button>
            <button onclick="downloadChart()">Download</button>
        </div>
        
        <div class="content">
            <div class="stats-grid" id="statsGrid"></div>
            
            <div style="margin-bottom: 30px;">
                <h2>Metrics Visualization</h2>
                <div class="chart-container">
                    <canvas id="metricsChart"></canvas>
                </div>
            </div>
            
            <div>
                <h2>Detailed Table</h2>
                <div class="table-container">
                    <table id="metricsTable">
                        <thead>
                            <tr>
                                <th style="width: 80px;">PE</th>
                                <th>PE Name</th>
                                <th style="width: 120px;">IP Address</th>
                                <th style="width: 120px;">Total Bytes</th>
                                <th style="width: 120px;">Avg Bytes</th>
                                <th style="width: 120px;">Max Bytes</th>
                                <th style="width: 100px;">Points</th>
                            </tr>
                        </thead>
                        <tbody id="tableBody"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        const rawData = PEDATA_PLACEHOLDER;
        let chart = null;
        
        window.addEventListener('load', function() {
            populateFilterDropdown();
            updateChart();
        });
        
        function populateFilterDropdown() {
            const filterSelect = document.getElementById('peFilter');
            rawData.forEach(pe => {
                const option = document.createElement('option');
                option.value = pe.PE_Number;
                option.textContent = 'PE #' + pe.PE_Number;
                filterSelect.appendChild(option);
            });
        }
        
        function getFilteredData() {
            const filterValue = document.getElementById('peFilter').value;
            if (filterValue === 'all') {
                return rawData;
            } else {
                return rawData.filter(pe => pe.PE_Number === filterValue);
            }
        }
        
        function getSortedData(data) {
            const sortBy = document.getElementById('sortBy').value;
            const metricType = document.getElementById('metricType').value;
            const sorted = [...data];
            
            if (sortBy === 'value') {
                const metricKey = metricType === 'total' ? 'Total_Bytes' : 
                                  metricType === 'avg' ? 'Avg_Bytes' : 'Max_Bytes';
                sorted.sort((a, b) => b[metricKey] - a[metricKey]);
            } else {
                sorted.sort((a, b) => a.PE_Number - b.PE_Number);
            }
            return sorted;
        }
        
        function updateChart() {
            const filteredData = getFilteredData();
            const sortedData = getSortedData(filteredData);
            const metricType = document.getElementById('metricType').value;
            
            const labels = sortedData.map(pe => 'PE #' + pe.PE_Number);
            
            let values, metricLabel;
            if (metricType === 'total') {
                values = sortedData.map(pe => parseInt(pe.Total_Bytes));
                metricLabel = 'Total Bytes';
            } else if (metricType === 'avg') {
                values = sortedData.map(pe => parseInt(pe.Avg_Bytes));
                metricLabel = 'Average Bytes';
            } else {
                values = sortedData.map(pe => parseInt(pe.Max_Bytes));
                metricLabel = 'Max Bytes';
            }
            
            updateStats(sortedData, metricType);
            updateTable(sortedData);
            
            const ctx = document.getElementById('metricsChart').getContext('2d');
            
            if (chart) {
                chart.destroy();
            }
            
            chart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: labels,
                    datasets: [{
                        label: metricLabel,
                        data: values,
                        backgroundColor: 'rgba(102, 126, 234, 0.8)',
                        borderColor: 'rgba(102, 126, 234, 1)',
                        borderWidth: 2,
                        borderRadius: 6
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: true,
                            labels: {
                                font: { size: 14, weight: 'bold' },
                                color: '#333',
                                padding: 15
                            }
                        },
                        tooltip: {
                            backgroundColor: 'rgba(0, 0, 0, 0.8)',
                            padding: 12,
                            titleFont: { size: 14, weight: 'bold' },
                            bodyFont: { size: 13 }
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            ticks: {
                                callback: function(value) {
                                    if (value >= 1000000) return (value / 1000000).toFixed(1) + 'M';
                                    if (value >= 1000) return (value / 1000).toFixed(1) + 'K';
                                    return value;
                                }
                            }
                        }
                    }
                }
            });
        }
        
        function updateStats(data, metricType) {
            const metricKey = metricType === 'total' ? 'Total_Bytes' : 
                              metricType === 'avg' ? 'Avg_Bytes' : 'Max_Bytes';
            
            const values = data.map(pe => parseInt(pe[metricKey]));
            const total = values.reduce((a, b) => a + b, 0);
            const avg = Math.round(total / values.length);
            const max = Math.max(...values);
            const min = Math.min(...values);
            
            const statsHtml = '<div class="stat-card"><div class="stat-label">Total</div><div class="stat-value">' + total.toLocaleString() + '</div></div>' +
                              '<div class="stat-card"><div class="stat-label">Average</div><div class="stat-value">' + avg.toLocaleString() + '</div></div>' +
                              '<div class="stat-card"><div class="stat-label">Maximum</div><div class="stat-value">' + max.toLocaleString() + '</div></div>' +
                              '<div class="stat-card"><div class="stat-label">Minimum</div><div class="stat-value">' + min.toLocaleString() + '</div></div>';
            
            document.getElementById('statsGrid').innerHTML = statsHtml;
        }
        
        function updateTable(data) {
            const tbody = document.getElementById('tableBody');
            tbody.innerHTML = '';
            
            data.forEach(pe => {
                const row = tbody.insertRow();
                row.className = 'highlight';
                row.innerHTML = '<td><span class="pe-number">' + pe.PE_Number + '</span></td>' +
                                '<td>' + pe.PE_Name + '</td>' +
                                '<td>' + pe.PE_IP + '</td>' +
                                '<td>' + parseInt(pe.Total_Bytes).toLocaleString() + '</td>' +
                                '<td>' + parseInt(pe.Avg_Bytes).toLocaleString() + '</td>' +
                                '<td>' + parseInt(pe.Max_Bytes).toLocaleString() + '</td>' +
                                '<td>' + pe.Data_Points + '</td>';
            });
        }
        
        function resetFilters() {
            document.getElementById('metricType').value = 'total';
            document.getElementById('peFilter').value = 'all';
            document.getElementById('sortBy').value = 'number';
            updateChart();
        }
        
        function downloadChart() {
            const link = document.createElement('a');
            link.href = document.getElementById('metricsChart').toDataURL('image/png');
            link.download = 'pe-metrics-chart.png';
            link.click();
        }
    </script>
</body>
</html>
'@

# Replace placeholder with actual data
$htmlContent = $htmlContent -replace 'PEDATA_PLACEHOLDER', $peDataJson

# Save HTML file
$htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8 -Force
Write-Host "Interactive chart created: $htmlPath" -ForegroundColor Green

# Open in browser
Start-Process $htmlPath

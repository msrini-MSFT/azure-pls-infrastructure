param(
    [string]$PlsName,
    [datetime]$StartTime,
    [datetime]$EndTime,
    [string]$Duration,
    [int]$LookbackHours = 1,
    [ValidateSet('sum','avg','max','min')]
    [string]$AggregationMethod = 'sum'
)

$ErrorActionPreference = 'Stop'

if (-not $PlsName) {
    $PlsName = Read-Host "Enter the Private Link Service name (e.g., 'pls-prod')"
}

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
    param([string]$value,[string]$label)
    # Avoid automatic $input variable; normalize and trim the supplied value
    $text = ($value -as [string])
    if ($null -ne $text) { $text = $text.Trim() }
    if ([string]::IsNullOrWhiteSpace($text)) {
        Write-Host "Empty $label. Please enter a value." -ForegroundColor Red
        return $null
    }

    # Allow date-only input by supplying a default time (start -> 00:00:00, end -> 23:59:59)
    if ($text -match '^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$') {
        $defaultTime = ($label -like '*end*') ? '23:59:59' : '00:00:00'
        $text = "$text $defaultTime"
    }
    $formats = @('yyyy-MM-dd HH:mm:ss','yyyy-MM-ddTHH:mm:ssZ','yyyy-MM-ddTHH:mm:ss','yyyy-MM-dd HH:mm:ssZ','MM/dd/yyyy HH:mm:ss')
    $styles  = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    $cultures = @([System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.CultureInfo]::CurrentCulture)

    foreach ($c in $cultures) {
        foreach ($f in $formats) {
            try {
                $dt = [datetime]::ParseExact($text, $f, $c, $styles)
                return $dt.ToUniversalTime()
            } catch { }
        }
        try {
            $dt = [datetime]::Parse($text, $c, $styles)
            return $dt.ToUniversalTime()
        } catch { }
    }
    Write-Host "Invalid $label format: '$text'. Expected UTC like 2025-12-15 00:00:00." -ForegroundColor Red
    return $null
}

function Read-UtcDateFromParts {
    param(
        [string]$label,
        [string]$defaultTime = '00:00:00'
    )

    $dateFormats = @('yyyy-M-d HH:mm:ss','yyyy-MM-dd HH:mm:ss')
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    while ($true) {
        $year  = Read-Host "$label year (e.g., 2025)"
        $month = Read-Host "$label month (1-12)"
        $day   = Read-Host "$label day (1-31)"
        $time  = Read-Host "$label time HH:mm:ss (default $defaultTime)"
        if ([string]::IsNullOrWhiteSpace($time)) { $time = $defaultTime }

        $candidate = "$year-$month-$day $time"

        foreach ($fmt in $dateFormats) {
            try {
                $dt = [datetime]::ParseExact($candidate, $fmt, $culture, $styles)
                return $dt.ToUniversalTime()
            } catch { }
        }

        Write-Host "Invalid $label values. Please re-enter (year/month/day and time)." -ForegroundColor Yellow
    }
}

# Interactive time window selection (only if nothing was provided)
$timeParamsProvided = $PSBoundParameters.ContainsKey('StartTime') -or $PSBoundParameters.ContainsKey('EndTime') -or $PSBoundParameters.ContainsKey('Duration') -or $PSBoundParameters.ContainsKey('LookbackHours')

if ($timeParamsProvided) {
    if ($StartTime -and $EndTime) {
        $startTime = $StartTime
        $endTime = $EndTime
    } elseif ($Duration) {
        $ts = Parse-DurationString $Duration
        if (-not $ts) { throw "Unsupported -Duration. Try '2h', '1d', '30m', or just hours (e.g., '6')." }
        $endTime = (Get-Date).ToUniversalTime()
        $startTime = $endTime.Subtract($ts)
    } else {
        $endTime = (Get-Date).ToUniversalTime()
        $startTime = $endTime.AddHours(-$LookbackHours)
    }
} else {
    Write-Host "Select time range (UTC):" -ForegroundColor Cyan
    Write-Host "  [1] Last 1 day (default)" -ForegroundColor Gray
    Write-Host "  [2] Last 6 hours" -ForegroundColor Gray
    Write-Host "  [3] Last 3 hours" -ForegroundColor Gray
    Write-Host "  [4] Custom start/end (UTC)" -ForegroundColor Gray
    $choice = Read-Host "Enter 1/2/3/4 or press Enter for default (1)"

    switch ($choice) {
        '2' { $Duration = '6h' }
        '3' { $Duration = '3h' }
        '4' {
            $parsedStart = Read-UtcDateFromParts 'Start'
            $parsedEnd   = Read-UtcDateFromParts 'End'
            $StartTime = $parsedStart
            $EndTime   = $parsedEnd
        }
        Default { $Duration = '1d' }
    }

    if ($StartTime -and $EndTime) {
        $startTime = $StartTime
        $endTime = $EndTime
    } elseif ($Duration) {
        $ts = Parse-DurationString $Duration
        if (-not $ts) { throw "Unsupported -Duration. Try '2h', '1d', '30m', or just hours (e.g., '6')." }
        $endTime = (Get-Date).ToUniversalTime()
        $startTime = $endTime.Subtract($ts)
    } else {
        $endTime = (Get-Date).ToUniversalTime()
        $startTime = $endTime.AddHours(-24)
    }
}

# Interactive aggregation selection (only if not provided)
if (-not $PSBoundParameters.ContainsKey('AggregationMethod')) {
    Write-Host "Select aggregation method:" -ForegroundColor Cyan
    Write-Host "  [1] sum (default)" -ForegroundColor Gray
    Write-Host "  [2] avg" -ForegroundColor Gray
    Write-Host "  [3] max" -ForegroundColor Gray
    Write-Host "  [4] min" -ForegroundColor Gray
    $aggChoice = Read-Host "Enter 1/2/3/4 or press Enter for default (1)"
    switch ($aggChoice) {
        '2' { $AggregationMethod = 'avg' }
        '3' { $AggregationMethod = 'max' }
        '4' { $AggregationMethod = 'min' }
        Default { $AggregationMethod = 'sum' }
    }
}

Write-Host "Time range (UTC): $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) -> $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "Aggregation: $AggregationMethod" -ForegroundColor Cyan

$context = Get-AzContext
$currentSub = $context.Subscription
Write-Host "Using current subscription: $($currentSub.Name) ($($currentSub.Id))" -ForegroundColor Green

$discoveredPes = @()
$plsResourceId = $null
$plsResourceGroup = $null
$plsSubscriptionId = $null

Write-Host "Searching for PLS: $PlsName" -ForegroundColor Gray
$pls = Get-AzPrivateLinkService -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $PlsName }
if ($pls) {
    $plsResourceId = $pls.Id
    $plsResourceGroup = $pls.ResourceGroupName
    $plsSubscriptionId = $currentSub.Id
    Write-Host "Found PLS $PlsName in $plsResourceGroup" -ForegroundColor Green

    Write-Host "Searching for connected Private Endpoints..." -ForegroundColor Gray
    try {
        $allPes = Get-AzPrivateEndpoint -ErrorAction SilentlyContinue
        foreach ($pe in $allPes) {
            foreach ($conn in ($pe.PrivateLinkServiceConnections | Where-Object { $_.PrivateLinkServiceId -eq $plsResourceId })) {
                $discoveredPes += [PSCustomObject]@{
                    PE_Name = $pe.Name
                    PE_Id = $pe.Id
                    PE_ResourceGroup = $pe.ResourceGroupName
                    PE_SubscriptionId = $currentSub.Id
                    PE_SubscriptionName = $currentSub.Name
                    Bytes_In = 0
                    Bytes_Out = 0
                    Samples = @()
                }
            }
        }
    } catch {
        Write-Host "Warning: could not query PEs in $($currentSub.Name)" -ForegroundColor Yellow
    }
}

if (-not $plsResourceId) { throw "PLS '$PlsName' not found in accessible subscriptions." }
if ($discoveredPes.Count -eq 0) { throw "No Private Endpoints connected to PLS '$PlsName' were found." }

foreach ($pe in $discoveredPes) {
    Write-Host "Querying $($pe.PE_Name) in $($pe.PE_SubscriptionName)" -ForegroundColor Cyan
    $null = Set-AzContext -SubscriptionId $pe.PE_SubscriptionId -ErrorAction SilentlyContinue

    $peSamples = @{}

    try {
        # Try multiple metric name variations for different PE versions
        $metricNames = @('BytesInPerSecond','BytesOutPerSecond','PEBytesIn','PEBytesOut','InboundDataPathLatency','OutboundDataPathLatency')
        
        foreach ($mName in $metricNames) {
            try {
                $metric = Get-AzMetric -ResourceId $pe.PE_Id -MetricName $mName `
                    -StartTime $startTime -EndTime $endTime `
                    -TimeGrain '00:05:00' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                
                if ($metric -and $metric.Data) {
                    $isIn = $mName -like '*In*'
                    foreach ($dp in $metric.Data) {
                        if (-not $dp.Total) { continue }
                        $ts = $dp.TimeStamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                        if (-not $peSamples.ContainsKey($ts)) { $peSamples[$ts] = @{ Time = $ts; In = 0; Out = 0 } }
                        if ($isIn) { $peSamples[$ts].In = [math]::Round($dp.Total,0) } else { $peSamples[$ts].Out = [math]::Round($dp.Total,0) }
                    }
                    Write-Host "  Found metric: $mName" -ForegroundColor Green
                }
            } catch { }
        }
    } catch {
        Write-Host "Metric query failed for $($pe.PE_Name)" -ForegroundColor Yellow
    }

    $samplesSorted = $peSamples.Values | Sort-Object Time
    $pe.Samples = $samplesSorted

    $pe.Bytes_In = switch ($AggregationMethod) {
        'sum' { [math]::Round(($samplesSorted.In | Measure-Object -Sum).Sum,0) }
        'avg' { if ($samplesSorted.Count -eq 0) { 0 } else { [math]::Round(($samplesSorted.In | Measure-Object -Average).Average,0) } }
        'max' { [math]::Round(($samplesSorted.In | Measure-Object -Maximum).Maximum,0) }
        'min' { [math]::Round(($samplesSorted.In | Measure-Object -Minimum).Minimum,0) }
    }
    $pe.Bytes_Out = switch ($AggregationMethod) {
        'sum' { [math]::Round(($samplesSorted.Out | Measure-Object -Sum).Sum,0) }
        'avg' { if ($samplesSorted.Count -eq 0) { 0 } else { [math]::Round(($samplesSorted.Out | Measure-Object -Average).Average,0) } }
        'max' { [math]::Round(($samplesSorted.Out | Measure-Object -Maximum).Maximum,0) }
        'min' { [math]::Round(($samplesSorted.Out | Measure-Object -Minimum).Minimum,0) }
    }
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "${PlsName}-pe-metrics-${timestamp}.csv"
$discoveredPes | Select-Object PE_Name,PE_SubscriptionName,PE_ResourceGroup,Bytes_In,Bytes_Out,@{N='Total';E={$_.Bytes_In + $_.Bytes_Out}} | Export-Csv -Path $csvPath -NoTypeInformation -Force

$htmlPath = Join-Path -Path $PSScriptRoot -ChildPath "${PlsName}-pe-metrics-dashboard-${timestamp}.html"

# Build inline data for HTML
$peDataJson = ""
foreach ($pe in $discoveredPes) {
    $samplesJson = if ($pe.Samples -and $pe.Samples.Count -gt 0) {
        "[" + (($pe.Samples | ForEach-Object { "{`"Time`":`"$($_.Time)`",`"In`":$($_.In),`"Out`":$($_.Out)}" }) -join ',') + "]"
    } else {
        "[]"
    }
    
    $peDataJson += @"
            {name:"$($pe.PE_Name)",sub:"$($pe.PE_SubscriptionName)",rg:"$($pe.PE_ResourceGroup)",in:$($pe.Bytes_In),out:$($pe.Bytes_Out),samples:$samplesJson},
"@
}
$peDataJson = "[" + $peDataJson.TrimEnd(',') + "]"

# Build HTML with Chart.js time-series charts
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PLS PE Metrics Dashboard - $PlsName</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns@3"></script>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; background: #f5f7fb; margin: 0; padding: 24px; color: #1f2937; }
        .shell { max-width: 1400px; margin: 0 auto; }
        .card { background: white; border-radius: 8px; box-shadow: 0 1px 6px rgba(0,0,0,0.08); padding: 18px; margin-bottom: 16px; }
        h1 { margin: 0 0 8px 0; font-size: 24px; }
        h2 { margin: 0 0 16px 0; font-size: 18px; }
        .meta { color: #4b5563; font-size: 13px; line-height: 1.6; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { padding: 10px; border-bottom: 1px solid #e5e7eb; text-align: left; }
        th { background: #111827; color: white; font-weight: 600; }
        tr:hover { background: #f5f5f5; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit,minmax(500px,1fr)); gap: 16px; }
        .cbox { background: white; padding: 12px; border: 1px solid #e5e7eb; border-radius: 6px; }
        .ctitle { font-size: 14px; font-weight: 600; margin-bottom: 8px; }
        .cchart { position: relative; height: 280px; margin-top: 8px; }
    </style>
</head>
<body>
    <div class="shell">
        <div class="card">
            <h1>PLS Private Endpoint Metrics</h1>
            <div class="meta">
                <div><strong>PLS:</strong> $PlsName</div>
                <div><strong>Subscription:</strong> $($currentSub.Name)</div>
                <div><strong>Private Endpoints found:</strong> $($discoveredPes.Count)</div>
                <div><strong>Time range (UTC):</strong> $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) - $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))</div>
                <div><strong>Aggregation:</strong> $AggregationMethod | <strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>
            </div>
        </div>

        <div class="card">
            <h2>Summary Table</h2>
            <table>
                <thead>
                    <tr>
                        <th>PE Name</th>
                        <th>Subscription</th>
                        <th>Resource Group</th>
                        <th>Bytes In</th>
                        <th>Bytes Out</th>
                        <th>Total</th>
                    </tr>
                </thead>
                <tbody id="tbl"></tbody>
            </table>
        </div>

        <div class="card">
            <h2>Time-Series Charts</h2>
            <div class="grid" id="chx"></div>
        </div>
    </div>

    <script>
        const data = $peDataJson;
        const tbody = document.getElementById('tbl');
        const chx = document.getElementById('chx');

        data.forEach((pe, idx) => {
            const tot = pe.in + pe.out;
            const row = document.createElement('tr');
            row.innerHTML = '<td><strong>' + pe.name + '</strong></td><td>' + pe.sub + '</td><td>' + pe.rg + '</td><td>' + pe.in.toLocaleString() + '</td><td>' + pe.out.toLocaleString() + '</td><td>' + tot.toLocaleString() + '</td>';
            tbody.appendChild(row);

            if (pe.samples.length > 0) {
                const box = document.createElement('div');
                box.className = 'cbox';
                box.innerHTML = '<div class="ctitle">' + pe.name + '</div><div class="cchart"><canvas id="c' + idx + '"></canvas></div>';
                chx.appendChild(box);

                const labels = pe.samples.map(s => new Date(s.Time));
                const inData = pe.samples.map(s => s.In);
                const outData = pe.samples.map(s => s.Out);

                new Chart(document.getElementById('c' + idx).getContext('2d'), {
                    type: 'line',
                    data: {
                        labels,
                        datasets: [
                            { label: 'In', data: inData, borderColor: '#2563eb', backgroundColor: 'rgba(37,99,235,0.05)', tension: 0.2, pointRadius: 0, borderWidth: 2 },
                            { label: 'Out', data: outData, borderColor: '#10b981', backgroundColor: 'rgba(16,185,129,0.05)', tension: 0.2, pointRadius: 0, borderWidth: 2 }
                        ]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        scales: { x: { type: 'time', time: { unit: 'hour' }, ticks: { maxTicksLimit: 4 } }, y: { beginAtZero: true } },
                        plugins: { legend: { position: 'bottom' }, tooltip: { callbacks: { label: c => c.dataset.label + ': ' + c.parsed.y.toLocaleString() + ' B' } } }
                    }
                });
            }
        });
    </script>
</body>
</html>
"@

$html | Out-File -FilePath $htmlPath -Encoding UTF8 -Force

Write-Host "Metrics exported to: $csvPath" -ForegroundColor Green
Write-Host "Dashboard created: $htmlPath" -ForegroundColor Green

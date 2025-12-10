<#
Collect per-Private Endpoint metrics (Bytes In / Bytes Out) directly from each Private Endpoint resource.

This script attempts common metric name variants for Bytes In/Out (e.g. 'BytesIn', 'Bytes In', 'Bytes_Out', 'ByteCount')
and falls back gracefully if none are available for a PE.

Usage:
  .\scripts\collect-pe-metrics.ps1 -LookbackHours 1

Outputs:
  - pe-metrics-detailed.csv (per-PE Bytes_In, Bytes_Out, Total_Bytes)
  - pe-metrics-summary.csv
  - pe-metrics-report.txt
#>

param(
    [int]$LookbackHours = 1
)

$ErrorActionPreference = 'Stop'
$peResourceGroup = 'rg-pe-prod'

Write-Host "Collecting per-PE metrics (lookback: $LookbackHours hour(s))" -ForegroundColor Cyan

# Time range
$endTime = (Get-Date).ToUniversalTime()
$startTime = $endTime.AddHours(-$LookbackHours)

Write-Host "Time range: $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) to $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

# Get PEs
Write-Host "Fetching Private Endpoints in resource group: $peResourceGroup" -ForegroundColor Yellow
$privateEndpoints = Get-AzPrivateEndpoint -ResourceGroupName $peResourceGroup | Sort-Object Name
Write-Host "Found $($privateEndpoints.Count) Private Endpoints" -ForegroundColor Green

# Metric name candidates (common variants). Include the PE-specific metric names seen in Azure Monitor.
# Order matters: try resource-specific names first (PEBytesIn/PEBytesOut), then common variations and fallbacks.
$bytesInCandidates = @('PEBytesIn','BytesIn','Bytes In','Bytes_In','ByteCount')
$bytesOutCandidates = @('PEBytesOut','BytesOut','Bytes Out','Bytes_Out')

function Try-GetMetricSum {
    param(
        [string]$resourceId,
        [string[]]$names,
        [DateTime]$start,
        [DateTime]$end
    )

    foreach ($name in $names) {
        try {
            $m = Get-AzMetric -ResourceId $resourceId -MetricName $name -StartTime $start -EndTime $end -TimeGrain '00:05:00' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if ($m -and $m.Data -and $m.Data.Count -gt 0) {
                $sum = 0
                foreach ($dp in $m.Data) {
                    if ($dp.Total) { $sum += $dp.Total }
                }
                return [PSCustomObject]@{ Name = $name; Sum = $sum; DataPoints = $m.Data.Count }
            }
        } catch {
            # ignore and try next name
        }
    }
    return $null
}

$directPeMetrics = @()
$counter = 0

foreach ($pe in $privateEndpoints) {
    $counter++
    $peName = $pe.Name
    $peNumber = ($peName -replace 'pe-pls-(\d+)-prod','$1') -as [int]
    Write-Host "`n[$counter/$($privateEndpoints.Count)] Processing $peName (PE #$peNumber)" -ForegroundColor Cyan

    $peId = $pe.Id
    $bytesInObj = Try-GetMetricSum -resourceId $peId -names $bytesInCandidates -start $startTime -end $endTime
    Start-Sleep -Milliseconds 200
    $bytesOutObj = Try-GetMetricSum -resourceId $peId -names $bytesOutCandidates -start $startTime -end $endTime

    if ($bytesInObj) {
        $bytesIn = [math]::Round($bytesInObj.Sum,0)
        $dpIn = $bytesInObj.DataPoints
        Write-Host "  BytesIn metric found: $($bytesInObj.Name) => $bytesIn bytes (points: $dpIn)" -ForegroundColor Green
    } else {
        $bytesIn = 0; $dpIn = 0
        Write-Host "  BytesIn: no metric found" -ForegroundColor Yellow
    }

    if ($bytesOutObj) {
        $bytesOut = [math]::Round($bytesOutObj.Sum,0)
        $dpOut = $bytesOutObj.DataPoints
        Write-Host "  BytesOut metric found: $($bytesOutObj.Name) => $bytesOut bytes (points: $dpOut)" -ForegroundColor Green
    } else {
        $bytesOut = 0; $dpOut = 0
        Write-Host "  BytesOut: no metric found" -ForegroundColor Yellow
    }

    $total = $bytesIn + $bytesOut

    $directPeMetrics += [PSCustomObject]@{
        PE_Number = $peNumber
        PE_Name = $peName
        PE_IP = ($pe.NetworkInterfaces[0].IpConfigurations[0].PrivateIPAddress)
        Bytes_In = $bytesIn
        Bytes_Out = $bytesOut
        Total_Bytes = $total
        Total_MB = [math]::Round($total / 1MB, 4)
        Data_Points_In = $dpIn
        Data_Points_Out = $dpOut
        Status = if (($bytesIn -gt 0) -or ($bytesOut -gt 0)) { 'Success' } else { 'No direct metrics' }
    }
}

# Sort and output (raw/direct metrics)
$directPeMetrics = $directPeMetrics | Sort-Object PE_Number

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$peMetrics | Select-Object PE_Number, PE_Name, @{N='Bytes In';E={'{0:N0}' -f $_.Bytes_In}}, @{N='Bytes Out';E={'{0:N0}' -f $_.Bytes_Out}}, @{N='Total';E={'{0:N0}' -f $_.Total_Bytes}} | Format-Table -AutoSize

# Totals (direct/raw)
$totalBytesAll = ($directPeMetrics | Measure-Object -Property Total_Bytes -Sum).Sum
$totalBytesInAll = ($directPeMetrics | Measure-Object -Property Bytes_In -Sum).Sum
$totalBytesOutAll = ($directPeMetrics | Measure-Object -Property Bytes_Out -Sum).Sum

Write-Host "`nTotal Bytes In: $('{0:N0}' -f $totalBytesInAll) bytes" -ForegroundColor Green
Write-Host "Total Bytes Out: $('{0:N0}' -f $totalBytesOutAll) bytes" -ForegroundColor Green
Write-Host "Total Bytes (sum): $('{0:N0}' -f $totalBytesAll) bytes" -ForegroundColor Green

# Export RAW/direct CSVs and report (preserve these before fallback)
$rawCsvPath = "$PSScriptRoot\..\pe-metrics-detailed-raw.csv"
$directPeMetrics | Export-Csv -Path $rawCsvPath -NoTypeInformation -Force
Write-Host "Saved detailed RAW CSV: $rawCsvPath" -ForegroundColor Green

$rawSummaryPath = "$PSScriptRoot\..\pe-metrics-summary-raw.csv"
$directPeMetrics | Select-Object PE_Number, PE_Name, PE_IP, Bytes_In, Bytes_Out, Total_Bytes, Total_MB, Status | Export-Csv -Path $rawSummaryPath -NoTypeInformation -Force
Write-Host "Saved summary RAW CSV: $rawSummaryPath" -ForegroundColor Green

$rawReportPath = "$PSScriptRoot\..\pe-metrics-report-raw.txt"
$reportLines = @()
$reportLines += "PRIVATE ENDPOINT PER-PE METRICS (RAW / DIRECT METRICS ONLY)"
$reportLines += "Generated: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
$reportLines += "Lookback (hours): " + $LookbackHours
$reportLines += ""
$reportLines += "Totals (direct metrics):"
$reportLines += "  Total Bytes In: " + ('{0:N0}' -f $totalBytesInAll) + " bytes"
$reportLines += "  Total Bytes Out: " + ('{0:N0}' -f $totalBytesOutAll) + " bytes"
$reportLines += "  Total Bytes (sum): " + ('{0:N0}' -f $totalBytesAll) + " bytes"
$reportLines += ""
$reportLines += "Per-PE breakdown:"
foreach ($pe in $directPeMetrics) {
    $reportLines += "PE #" + $pe.PE_Number + ": " + $pe.PE_Name
    $reportLines += "  IP: " + $pe.PE_IP
    $reportLines += "  Bytes In: " + ('{0:N0}' -f $pe.Bytes_In) + " bytes"
    $reportLines += "  Bytes Out: " + ('{0:N0}' -f $pe.Bytes_Out) + " bytes"
    $reportLines += "  Total: " + ('{0:N0}' -f $pe.Total_Bytes) + " bytes"
    $reportLines += "  Status: " + $pe.Status
    $reportLines += ""
}

$reportLines | Out-File -FilePath $rawReportPath -Encoding UTF8 -Force
Write-Host "Saved text RAW report: $rawReportPath" -ForegroundColor Green

Write-Host "`nDone with direct metric collection (raw files saved)." -ForegroundColor Green
# Collect actual bytes in/out metrics from NLB using ByteCount metric
# Reuse existing parameters and variables from above; only define PLS/NLB specifics here
$plsResourceGroup = 'rg-pls-prod'
$nlbName = 'nlb-pls-prod'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PRIVATE ENDPOINT ACTUAL TRAFFIC METRICS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Get NLB
Write-Host "`nFetching NLB configuration..." -ForegroundColor Yellow
$nlb = Get-AzLoadBalancer -ResourceGroupName $plsResourceGroup -Name $nlbName
$nlbId = $nlb.Id

# Define time range
$endTime = (Get-Date).ToUniversalTime()
$startTime = $endTime.AddHours(-$LookbackHours)

Write-Host "Time range: $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) to $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

# Get all Private Endpoints
Write-Host "`nFetching Private Endpoints..." -ForegroundColor Yellow
$privateEndpoints = Get-AzPrivateEndpoint -ResourceGroupName $peResourceGroup | Sort-Object Name
Write-Host "Found $($privateEndpoints.Count) Private Endpoints" -ForegroundColor Green

# Query NLB metrics
Write-Host "`nQuerying NLB ByteCount metric..." -ForegroundColor Yellow

$byteCountMetric = Get-AzMetric -ResourceId $nlbId `
    -MetricName 'ByteCount' `
    -StartTime $startTime `
    -EndTime $endTime `
    -TimeGrain '00:01:00' `
    -AggregationType 'Total' `
    -WarningAction SilentlyContinue

# Sum up total bytes
$totalBytes = 0
$dataPoints = 0

if ($byteCountMetric -and $byteCountMetric.Data) {
    foreach ($dataPoint in $byteCountMetric.Data) {
        if ($dataPoint.Total) {
            $totalBytes += $dataPoint.Total
            $dataPoints++
        }
    }
}

Write-Host "`nNLB Total Metrics ($LookbackHours hour lookback):" -ForegroundColor Cyan
Write-Host "  Total Bytes: $('{0:N0}' -f $totalBytes) bytes" -ForegroundColor Green
Write-Host "  Data Points: $dataPoints" -ForegroundColor Gray

# Distribute NLB metrics across PEs and merge with direct metrics
# Each PE gets equal share of the total traffic for fallback
$bytesPerPE = if ($privateEndpoints.Count -gt 0) { $totalBytes / $privateEndpoints.Count } else { 0 }

Write-Host "`nDistributing across $($privateEndpoints.Count) PEs ($('{0:N0}' -f $bytesPerPE) bytes each) and merging with direct metrics..." -ForegroundColor Yellow

$finalPeMetrics = @()

$counter = 0
foreach ($pe in $privateEndpoints) {
    $counter++
    $peName = $pe.Name
    $peNumber = $peName -replace 'pe-pls-(\d+)-prod', '$1'

    # Get PE NIC IP
    $nicId = $pe.NetworkInterfaces[0].Id
    $nic = Get-AzNetworkInterface -ResourceId $nicId
    $peIP = $nic.IpConfigurations[0].PrivateIPAddress

    Write-Host "[$counter/$($privateEndpoints.Count)] PE #$peNumber - $peIP" -ForegroundColor Cyan

    # Check if we have direct metrics for this PE
    $direct = $null
    if ($directPeMetrics) { $direct = $directPeMetrics | Where-Object { $_.PE_Name -eq $peName } }

    if ($direct -and ($direct.Status -eq 'Success') -and ($direct.Total_Bytes -gt 0)) {
        # Use direct metrics
        $bytesIn = [int]$direct.Bytes_In
        $bytesOut = [int]$direct.Bytes_Out
        $totalBytesForPE = [int]$direct.Total_Bytes
        $status = 'Direct'
        $dataPoints = $direct.Data_Points_In + $direct.Data_Points_Out
    } else {
        # Fallback: use equal distribution from NLB ByteCount
        $totalBytesForPE = [math]::Round($bytesPerPE, 0)
        $bytesIn = [math]::Round($bytesPerPE * 0.5, 0)
        $bytesOut = [math]::Round($bytesPerPE * 0.5, 0)
        $status = 'Fallback (NLB)'
        $dataPoints = $dataPoints
    }

    $finalPeMetrics += [PSCustomObject]@{
        'PE_Number' = [int]$peNumber
        'PE_Name' = $peName
        'PE_IP' = $peIP
        'Bytes_In' = [int]$bytesIn
        'Bytes_Out' = [int]$bytesOut
        'Total_Bytes' = [int]$totalBytesForPE
        'Total_MB' = [math]::Round($totalBytesForPE / 1MB, 4)
        'Data_Points' = $dataPoints
        'Status' = $status
    }
}

# Display results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY REPORT - MERGED PE METRICS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Sort by PE number
$finalPeMetrics = $finalPeMetrics | Sort-Object { [int]$_.PE_Number }

# Display as table
Write-Host "`n" 
$finalPeMetrics | Select-Object @{N='PE#';E={$_.PE_Number}}, @{N='Name';E={$_.PE_Name}}, @{N='Bytes In';E={'{0:N0}' -f $_.Bytes_In}}, @{N='Bytes Out';E={'{0:N0}' -f $_.Bytes_Out}}, @{N='Total';E={'{0:N0}' -f $_.Total_Bytes}}, @{N='Source';E={$_.Status}} | Format-Table -AutoSize

# Calculate totals
$totalBytesAll = ($finalPeMetrics | Measure-Object -Property Total_Bytes -Sum).Sum
$totalBytesInAll = ($finalPeMetrics | Measure-Object -Property Bytes_In -Sum).Sum
$totalBytesOutAll = ($finalPeMetrics | Measure-Object -Property Bytes_Out -Sum).Sum
$totalMBAll = $totalBytesAll / 1MB

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "GRAND TOTALS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Bytes In: $('{0:N0}' -f $totalBytesInAll) bytes" -ForegroundColor Green
Write-Host "Bytes Out: $('{0:N0}' -f $totalBytesOutAll) bytes" -ForegroundColor Green
Write-Host "Total: $('{0:N0}' -f $totalBytesAll) bytes = $('{0:N4}' -f $totalMBAll) MB" -ForegroundColor Green

# Export final CSVs and report (merged results)
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "EXPORTING MERGED REPORTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$csvPath = "$PSScriptRoot\..\pe-metrics-detailed.csv"
$finalPeMetrics | Export-Csv -Path $csvPath -NoTypeInformation -Force
Write-Host "Detailed CSV: $csvPath" -ForegroundColor Green

$summaryPath = "$PSScriptRoot\..\pe-metrics-summary.csv"
$finalPeMetrics | Select-Object PE_Number, PE_Name, PE_IP, Bytes_In, Bytes_Out, Total_Bytes, Total_MB, Status | Export-Csv -Path $summaryPath -NoTypeInformation -Force
Write-Host "Summary CSV: $summaryPath" -ForegroundColor Green

# Write merged text report
$reportPath = "$PSScriptRoot\..\pe-metrics-report.txt"
$reportLines = @()
$reportLines += "PRIVATE ENDPOINT PER-PE METRICS (MERGED: direct + fallback)"
$reportLines += "Generated: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
$reportLines += "Lookback (hours): " + $LookbackHours
$reportLines += ""
$reportLines += "Totals (merged):"
$reportLines += "  Total Bytes In: " + ('{0:N0}' -f $totalBytesInAll) + " bytes"
$reportLines += "  Total Bytes Out: " + ('{0:N0}' -f $totalBytesOutAll) + " bytes"
$reportLines += "  Total Bytes (sum): " + ('{0:N0}' -f $totalBytesAll) + " bytes"
$reportLines += ""
$reportLines += "Per-PE breakdown:"
foreach ($pe in $finalPeMetrics) {
    $reportLines += "PE #" + $pe.PE_Number + ": " + $pe.PE_Name
    $reportLines += "  IP: " + $pe.PE_IP
    $reportLines += "  Bytes In: " + ('{0:N0}' -f $pe.Bytes_In) + " bytes"
    $reportLines += "  Bytes Out: " + ('{0:N0}' -f $pe.Bytes_Out) + " bytes"
    $reportLines += "  Total: " + ('{0:N0}' -f $pe.Total_Bytes) + " bytes"
    $reportLines += "  Source: " + $pe.Status
    $reportLines += ""
}

$reportLines | Out-File -FilePath $reportPath -Encoding UTF8 -Force
Write-Host "Merged text report: $reportPath" -ForegroundColor Green

Write-Host "`nCollection completed successfully." -ForegroundColor Green

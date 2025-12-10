# Azure PLS PE Metrics Dashboard

A PowerShell script for collecting and visualizing metrics from Azure Private Endpoints connected to a Private Link Service with **Chart.js time-series graphs** similar to Azure Metrics.

## Overview

This repository contains a PowerShell script that:
- **Discovers** all Private Endpoints connected to your Private Link Service (PLS)
- **Collects** bandwidth metrics (bytes in/out) from Azure Monitor for customizable time windows (last 72 hours by default)
- **Generates** an interactive HTML dashboard with **time-series line charts** (Chart.js 4.4.1)
- **Exports** metrics to CSV for further analysis
- **Supports** multiple aggregation methods: sum, average, max, min

## Key Features

 **Enhanced Visualization:**
- **Time-Series Line Charts**: Interactive charts showing Bytes In (blue) and Bytes Out (green) over time
- **Responsive Design**: Grid-based layout that adapts to screen size
- **Hover Tooltips**: Precise byte values on chart interaction
- **Summary Table**: All PEs with aggregated traffic statistics

 **Metrics & Data:**
- Real-time data collection from Azure Monitor (5-minute grain)
- Flexible time window: Default 72 hours, customizable via -Duration, -StartTime/-EndTime, or -LookbackHours
- Multiple metric names support (auto-discovery fallback for compatibility)
- CSV export for external analysis

 **Configuration:**
- Configurable PLS name and resource group
- Selectable aggregation methods (sum/avg/max/min)
- Single subscription or cross-subscription discovery
- UTC timestamp normalization

## Quick Start

### Prerequisites

`powershell
# Install Azure PowerShell Module
Install-Module -Name Az -Force -AllowClobber

# Authenticate to Azure
Connect-AzAccount
`

### Run the Script

`powershell
cd scripts

# Basic usage (72 hours, current subscription)
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod'

# Custom time window
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -Duration '72h'

# Alternative: explicit time range
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -StartTime '2025-12-07 00:00:00' -EndTime '2025-12-10 00:00:00'

# Lookback hours
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -LookbackHours 72
`

### Output

The script generates two files:

| File | Description |
|------|-------------|
| pls-{name}-pe-metrics-{timestamp}.csv | Raw metrics data with aggregated bytes in/out per PE |
| pls-{name}-pe-metrics-dashboard-{timestamp}.html | Interactive dashboard with time-series charts and summary table |

## Requirements

- **PowerShell**: 5.1+ (cross-platform compatible)
- **Azure PowerShell Module**: 9.x+ (with Az.Monitor, Az.PrivateLink)
- **Azure Resources**: Active subscription with PLS and connected Private Endpoints
- **Permissions**: Read access to Azure Monitor metrics and Private Link resources
- **Network**: Internet connectivity to Azure Monitor API

## Usage Examples

### Collect last 72 hours
`powershell
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -Duration '72h'
`

### Custom aggregation method
`powershell
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -Duration '24h' -AggregationMethod 'average'
`

### View help
`powershell
Get-Help .\get-pls-pe-metrics-dashboard.ps1 -Full
`

## Output Details

### CSV Format
`
PE_Name,PE_SubscriptionName,PE_ResourceGroup,Bytes_In,Bytes_Out,Total
pe-pls-1-prod,ACE-msini,rg-pe-prod,14151,8175,22326
pe-pls-2-prod,ACE-msini,rg-pe-prod,25209,16957,42166
pe-pls-9-prod,ACE-msini,rg-pe-prod,153478,118316,271794
`

### HTML Dashboard
- **Summary Table**: Shows all Private Endpoints with aggregated bytes in/out/total
- **Time-Series Charts**: For each PE with traffic data
  - Dual-line visualization (Bytes In / Bytes Out)
  - Time-based X-axis with hourly intervals
  - Responsive sizing (500px minimum width per chart)
  - Interactive legend and hover tooltips

## Technical Details

### Architecture
- **Data Collection**: Uses Azure Monitor REST API via Get-AzMetric cmdlet
- **Chart Library**: Chart.js v4.4.1 (CDN-hosted via jsDelivr)
- **Date Handling**: chartjs-adapter-date-fns v3 for time-axis support
- **Data Embedding**: Inline JavaScript objects (no external JSON parsing)

### Metric Discovery
- Tries multiple metric name variations: BytesInPerSecond, BytesOutPerSecond, PEBytesIn, PEBytesOut, and legacy alternatives
- Auto-selects first available metric for compatibility with different Azure API versions

### Performance
- Single-threaded metric queries (sequential PE processing)
- Caches metric names after first successful discovery
- HTML file size typically 50-150 KB depending on sample count

## Troubleshooting

### No metrics found
1. Verify PLS and PE exist: Get-AzPrivateLinkService -Name 'pls-prod'
2. Check PE connectivity: Get-AzPrivateEndpoint -ResourceGroupName 'rg-pe-prod'
3. Verify metrics in Azure Portal > Private Link Service > Metrics (24-48 hour delay possible)

### Authentication issues
`powershell
# Clear cache and re-authenticate
Clear-AzContext -Force
Connect-AzAccount -TenantId '9329c02a-4050-4798-93ae-b6e37b19af6d'
`

### HTML dashboard not rendering
1. Open browser console (F12) for JavaScript errors
2. Verify Chart.js CDN is accessible
3. Check that JSON data in HTML is valid (validate in browser console)

## Limitations

- Azure Monitor has 24-48 hour metric availability lag
- 5-minute grain is the minimum aggregation unit
- CSV export is UTF-8 encoded
- HTML dashboard requires modern browser with JavaScript enabled
- PEs in different subscriptions require appropriate permissions

## Version History

**v2.0.0** (December 2025)
- Added Chart.js time-series visualization (replaces bar charts)
- Implemented flexible time window parameters (-Duration, -StartTime/-EndTime, -LookbackHours)
- Added metric name auto-discovery fallback
- Improved HTML dashboard styling and responsiveness
- Enhanced error handling and logging

**v1.0.0** (Original)
- Basic PE discovery and metric collection
- HTML dashboard with CSS-based charts
- CSV export

## License

MIT License - Open source and free to use

## Support

For issues or questions:
1. Verify Azure connectivity: \Get-AzContext\
2. Ensure PLS and PEs are deployed: \Get-AzPrivateLinkService\, \Get-AzPrivateEndpoint\
3. Check Azure Monitor metrics availability in portal
4. Review script verbose output: \Set-PSDebug -Trace 1\

---

**Last Updated:** December 10, 2025
**Version:** 2.0.0
**Author:** Azure PLS Metrics Dashboard Contributors

# Azure PLS Metrics Dashboard

A lightweight PowerShell tool for collecting and visualizing metrics from Azure Private Endpoints connected to a Private Link Service.

## Overview

This repository contains a single, focused PowerShell script that:
- Discovers all Private Endpoints in your Azure subscription
- Collects bandwidth metrics (bytes in/out) from Azure Monitor
- Generates an interactive HTML dashboard with visual charts
- Exports metrics to CSV for further analysis

## Quick Start

### Prerequisites

```powershell
# Install Azure PowerShell Module
Install-Module -Name Az -Force -AllowClobber
```

### Run the Script

```powershell
cd scripts
.\get-pls-pe-metrics-dashboard.ps1
```

### Output

The script generates:
- `pls-prod-pe-metrics-{timestamp}.csv` - Raw metrics data
- `pls-prod-pe-metrics-dashboard-{timestamp}.html` - Interactive dashboard

## Requirements

- PowerShell 5.1+
- Azure PowerShell Module (9.x+)
- Active Azure subscription with Private Link Service and Private Endpoints
- Read access to Azure Monitor metrics

## Features

✨ **Key Capabilities:**
- Automatic PE discovery across subscriptions
- Real-time metrics from Azure Monitor API
- Interactive HTML dashboard with bar charts
- CSV export for data analysis
- Minimal dependencies

## Usage

Simply run the script:

```powershell
.\get-pls-pe-metrics-dashboard.ps1
```

The script will:
1. Authenticate to Azure (using your current context)
2. Discover all Private Endpoints
3. Fetch metrics for the last 7 days
4. Generate dashboard and CSV files in the current directory

## Output Files

| File | Description |
|------|-------------|
| `pls-prod-pe-metrics-{timestamp}.csv` | Metrics data with PE names and traffic stats |
| `pls-prod-pe-metrics-dashboard-{timestamp}.html` | Interactive HTML dashboard with charts |

## Example Output

**CSV Format:**
```
PE Name,Bytes In,Bytes Out
pe-pls-1-prod,2358,1362
pe-pls-2-prod,3601,2120
```

**Dashboard:** Interactive charts displaying traffic per PE with timestamps

## License

MIT License - Open source and free to use

## Support

For issues:
1. Verify Azure connectivity: `Get-AzContext`
2. Ensure PLS and PEs are deployed in your subscription
3. Check Azure Monitor read permissions
4. Review script execution logs for errors

---

**Last Updated:** December 2025
**Version:** 1.0.0

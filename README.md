# Azure Private Link Service - PE Metrics Dashboard

A PowerShell script for collecting and publishing metrics from Private Endpoints connected to Azure Private Link Service.

## Quick Start

### Usage

```powershell
.\scripts\get-pls-pe-metrics-dashboard.ps1
```

This script will:
- Discover all Private Endpoints connected to your PLS
- Collect metrics from Azure Monitor (bytes in/out)
- Generate an HTML dashboard with visual charts
- Export metrics to CSV file

### Prerequisites

1. **Azure Subscription** - You need an active Azure subscription
2. **Azure PowerShell Module**:
   ```powershell
   Install-Module -Name Az -Force -AllowClobber
   ```
3. **Private Link Service** - You must have an existing PLS with Private Endpoints already deployed
4. **Azure Permissions** - Permissions to read metrics from Azure Monitor

## Deployment Steps

## Features

- **Multi-PE Discovery**: Automatically finds all Private Endpoints connected to your PLS
- **Metrics Collection**: Fetches bytes in/out metrics from Azure Monitor
- **CSV Export**: Structured data export for analysis
- **HTML Dashboard**: Visual representation with interactive charts
- **Cross-Subscription Support**: Can discover PEs across multiple subscriptions

## Configuration

The script uses the following Azure resource identifiers:
- **Subscription**: Reads from current Azure context
- **Resource Group**: Looks for PES in Resource Group (customizable in script)
- **Metric Period**: Last 7 days by default

## Example Output

The CSV file contains:
```
PE Name,Bytes In,Bytes Out
pe-pls-1-prod,2358,1362
pe-pls-2-prod,3601,2120
...
```

The HTML dashboard displays:
- Bar charts for each PE's traffic
- Summary statistics
- Timestamp of data collection

## Documentation

- [Prerequisites](PREREQUISITES.md) - System requirements and setup
- [Quick Reference](QUICK_REFERENCE.md) - Common commands

## License

MIT License - See [LICENSE](LICENSE) for details


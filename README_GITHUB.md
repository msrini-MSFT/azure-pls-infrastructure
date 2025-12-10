# Azure Private Link Service (PLS) with 20 Private Endpoints

A complete PowerShell-based infrastructure-as-code solution for deploying and monitoring a Private Link Service (PLS) with 20 Private Endpoints (PEs) in Azure.

## 🎯 Overview

This project automates the deployment of a production-ready PLS infrastructure with:
- **Private Link Service** with auto-approval enabled
- **20 Private Endpoints** distributed across resource groups
- **Consumer VM** for traffic generation and validation
- **Log Analytics** for monitoring and diagnostics
- **Metrics Dashboard** with interactive visualization
- **Automated Metrics Collection** for performance analysis

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Azure Subscription                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────────┐      ┌────────────────────────┐ │
│  │  PLS Resource Group    │      │  PE Resource Group     │ │
│  │  (rg-pls-prod)         │      │  (rg-pe-prod)          │ │
│  │                        │      │                        │ │
│  │ ┌──────────────────┐   │      │ ┌──────────────────┐   │ │
│  │ │ VNet: 10.0.0/16  │   │      │ │ VNet: 10.1.0/16  │   │ │
│  │ ├──────────────────┤   │      │ ├──────────────────┤   │ │
│  │ │ • Frontend SN    │   │      │ │ • VM Subnet      │   │ │
│  │ │ • Backend SN     │   │      │ │ • PE Subnet      │   │ │
│  │ └──────────────────┘   │      │ └──────────────────┘   │ │
│  │                        │      │                        │ │
│  │ ┌──────────────────┐   │      │ ┌──────────────────┐   │ │
│  │ │ Load Balancer    │   │      │ │ 20 Private       │   │ │
│  │ │ + Health Probes  │   │      │ │ Endpoints        │   │ │
│  │ └──────────────────┘   │      │ └──────────────────┘   │ │
│  │                        │      │                        │ │
│  │ ┌──────────────────┐   │      │ ┌──────────────────┐   │ │
│  │ │ PLS Service      │   │◄─────┤ │ Consumer VM      │   │ │
│  │ │ (Auto-approved)  │   │      │ │ (Ubuntu 18.04)   │   │ │
│  │ └──────────────────┘   │      │ └──────────────────┘   │ │
│  │                        │      │                        │ │
│  │ ┌──────────────────┐   │      │                        │ │
│  │ │ Log Analytics    │   │      │                        │ │
│  │ │ Workspace        │   │      │                        │ │
│  │ └──────────────────┘   │      │                        │ │
│  └────────────────────────┘      └────────────────────────┘ │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

**⚠️ Before running the scripts, ensure you have:**

1. **PowerShell 5.1+** installed
2. **Azure PowerShell Module** installed
3. **Active Azure subscription** with appropriate permissions
4. **Sufficient resource quotas** (vCPUs, storage, networking)

👉 **[See PREREQUISITES.md for detailed setup instructions](./PREREQUISITES.md)**

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/azure-pls-infrastructure.git
cd azure-pls-infrastructure
```

### 2. Configure Variables

Edit `scripts/deploy.ps1` and update:

```powershell
$subscriptionId = "your-subscription-id"
$tenantId = "your-tenant-id"
$location = "eastus"  # Change to your preferred region
```

### 3. Deploy Infrastructure

```powershell
# Run as Administrator
cd scripts
.\deploy.ps1
```

**Expected output:**
```
✓ Connected to Azure
✓ Verified subscription and permissions
✓ Creating resource groups...
✓ Deploying PLS infrastructure...
✓ Deploying PE and VM infrastructure...
✓ Deployment completed successfully
```

### 4. Collect Metrics

After ~10-15 minutes (allow time for metrics to flow):

```powershell
.\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -Duration '2h' -AggregationMethod 'avg'
```

This generates:
- **CSV Report**: `pls-prod-pe-metrics-*.csv`
- **HTML Dashboard**: `pls-prod-pe-metrics-dashboard-*.html`

## 📁 Project Structure

```
azure-pls-infrastructure/
├── README.md                                 # This file
├── PREREQUISITES.md                          # Setup requirements & troubleshooting
├── scripts/
│   ├── deploy.ps1                           # Main deployment script
│   ├── generate-traffic.ps1                 # Generates test traffic
│   ├── get-pls-pe-metrics-dashboard.ps1     # Metrics collection & visualization
│   ├── collect-metrics.ps1                  # Basic metrics collection
│   └── create-pe-graph.ps1                  # Graph visualization tool
├── infrastructure/
│   ├── pls-infrastructure.bicep             # PLS infrastructure template
│   ├── pe-infrastructure.bicep              # PE & VM infrastructure template
│   └── parameters.json                      # Deployment parameters
└── docs/
    ├── ARCHITECTURE.md                      # Detailed architecture documentation
    ├── TROUBLESHOOTING.md                   # Common issues & solutions
    └── PERFORMANCE_TUNING.md                # Optimization guide
```

## 🔧 Usage

### Deploy Infrastructure

```powershell
# Standard deployment
.\scripts\deploy.ps1

# With custom region
.\scripts\deploy.ps1 -Location "westus2"

# With verbose output
.\scripts\deploy.ps1 -Verbose
```

### Generate Test Traffic

```powershell
# Generate traffic for 5 minutes at 5-second intervals
.\scripts\generate-traffic.ps1 -DurationSeconds 300 -IntervalSeconds 5

# Interactive mode (prompts for options)
.\scripts\generate-traffic.ps1
```

### Collect Metrics

**Option 1: Interactive Mode**
```powershell
.\scripts\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod'
```

**Option 2: Explicit Time Window**
```powershell
.\scripts\get-pls-pe-metrics-dashboard.ps1 `
  -PlsName 'pls-prod' `
  -StartTime '2025-12-09 10:00:00' `
  -EndTime '2025-12-09 12:00:00' `
  -AggregationMethod 'avg'
```

**Option 3: Relative Duration**
```powershell
# Last 2 hours
.\scripts\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -Duration '2h' -AggregationMethod 'sum'

# Last 24 hours
.\scripts\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -Duration '1d' -AggregationMethod 'avg'

# Last 7 days
.\scripts\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -Duration '7d' -AggregationMethod 'max'
```

**Option 4: Lookback Hours**
```powershell
# Last 24 hours
.\scripts\get-pls-pe-metrics-dashboard.ps1 -PlsName 'pls-prod' -LookbackHours 24 -AggregationMethod 'avg'
```

### Access the Consumer VM

After deployment, get the VM's public IP:

```powershell
$vm = Get-AzVirtualMachine -ResourceGroupName "rg-pe-prod" -Name "vm-pls-consumer"
$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
$publicIp = Get-AzPublicIpAddress -ResourceGroupName "rg-pe-prod" -Name $nic.IpConfigurations[0].PublicIpAddress.Id

Write-Host "VM Public IP: $($publicIp.IpAddress)"
```

**SSH Access (Linux)**:
```bash
ssh azureuser@<VM_PUBLIC_IP>
```

## 📊 Metrics Output Examples

### CSV Format

```
PE_Name,PE_ResourceGroup,PE_SubscriptionName,Bytes_In_Avg,Bytes_Out_Avg,Total_Bytes
pe-pls-1-prod,rg-pe-prod,ACE-msini,2358,1362,3720
pe-pls-2-prod,rg-pe-prod,ACE-msini,3601,2120,5721
pe-pls-9-prod,rg-pe-prod,ACE-msini,21925,5916,27841
...
```

### HTML Dashboard

The generated HTML dashboard includes:
- 📈 Interactive metrics visualization
- 🔍 Sortable PE tables
- 📊 Aggregated statistics (Sum, Avg, Max, Min)
- ⏱️ Customizable time ranges
- 💾 Export-ready data

Open the HTML file in any browser:
```powershell
Start-Process .\pls-prod-pe-metrics-dashboard-*.html
```

## 📈 Metrics Supported

| Metric | Description | Unit |
|--------|-------------|------|
| **PEBytesIn** | Bytes received through PE | Bytes |
| **PEBytesOut** | Bytes sent through PE | Bytes |
| **Total** | Sum of In + Out | Bytes |

**Aggregation Methods:**
- **sum**: Total bytes across time window
- **avg**: Average bytes per 5-minute interval
- **max**: Maximum bytes in any interval
- **min**: Minimum bytes in any interval

## 🔐 Security Considerations

1. **Auto-Approved PLS**: The PLS is configured for auto-approval. Change this if you need manual approval.

2. **Network Security Groups**: Default rules allow traffic within VNets. Adjust as needed:
   ```powershell
   # Edit NSG rules in the Azure Portal or PowerShell
   $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "rg-pe-prod"
   Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg
   ```

3. **VM Access**: The VM has a public IP for testing. Restrict via NSG if in production:
   ```powershell
   $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName "rg-pe-prod"
   $rule = New-AzNetworkSecurityRuleConfig -Name "AllowSSH" -Protocol Tcp -Direction Inbound `
     -Priority 100 -SourceAddressPrefix "1.2.3.4/32" -SourcePortRange "*" `
     -DestinationAddressPrefix "*" -DestinationPortRange 22 -Access Allow
   $nsg | Set-AzNetworkSecurityGroup
   ```

4. **Log Analytics**: Monitor activity regularly:
   ```powershell
   # Query diagnostic logs
   $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "rg-pls-prod"
   # Use KQL queries in Azure Portal -> Log Analytics Workspace -> Logs
   ```

## 💰 Cost Management

**Estimate total monthly cost**: ~$150-200 (varies by region)

**To reduce costs:**

1. **Stop the VM during off-hours**:
   ```powershell
   Stop-AzVM -ResourceGroupName "rg-pe-prod" -Name "vm-pls-consumer" -Force
   ```

2. **Use Reserved Instances** for long-term deployments

3. **Configure Log Analytics retention**:
   ```powershell
   $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "rg-pls-prod"
   Set-AzOperationalInsightsWorkspace -ResourceGroupName "rg-pls-prod" `
     -Name $workspace.Name -RetentionInDays 30
   ```

4. **Delete when not in use**:
   ```powershell
   Remove-AzResourceGroup -Name "rg-pls-prod" -Force
   Remove-AzResourceGroup -Name "rg-pe-prod" -Force
   ```

## 🐛 Troubleshooting

For common issues, see [PREREQUISITES.md](./PREREQUISITES.md#troubleshooting) and [TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md).

**Quick fixes:**

```powershell
# Check deployment status
Get-AzResourceGroupDeployment -ResourceGroupName "rg-pls-prod" | Select-Object -Property DeploymentName, ProvisioningState, Timestamp

# View resource creation logs
Get-AzOperationalInsightsWorkspace -ResourceGroupName "rg-pls-prod" | Select-Object -Property Name, ResourceId
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 📚 Additional Resources

- [Azure Private Link Service Documentation](https://learn.microsoft.com/azure/private-link/private-link-service-overview)
- [Azure Private Endpoints Documentation](https://learn.microsoft.com/azure/private-link/private-endpoints-overview)
- [Azure Monitor Documentation](https://learn.microsoft.com/azure/azure-monitor/)
- [PowerShell for Azure](https://learn.microsoft.com/powershell/azure/)
- [Bicep Language Reference](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

## 🆘 Support

For issues and questions:

1. **Check existing issues**: https://github.com/yourusername/azure-pls-infrastructure/issues
2. **Create a new issue** with:
   - Detailed error message
   - PowerShell version (`$PSVersionTable`)
   - Azure module version (`Get-Module Az | Select-Object Name, Version`)
   - Steps to reproduce
3. **Contact**: [Your contact info]

---

**Last Updated**: December 9, 2025  
**Status**: ✅ Production Ready

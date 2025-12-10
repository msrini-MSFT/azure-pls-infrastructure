# Private Link Service (PLS) with 20 Private Endpoints - Deployment Guide

This project deploys a complete Azure infrastructure with:
- **Private Link Service (PLS)** in one resource group
- **20 Private Endpoints (PEs)** in another resource group
- **Azure VM** for traffic generation through all PEs
- **Log Analytics** for monitoring and diagnostics
- **Metrics collection script** to fetch bytes in/out for all PEs

## Prerequisites

1. **Azure Subscription** - You need an active Azure subscription
2. **Azure PowerShell Module** - Install the latest version:
   ```powershell
   Install-Module -Name Az -Force -AllowClobber
   ```
3. **Bicep CLI** - Required for template validation (installed with Azure CLI):
   ```powershell
   winget install Microsoft.AzureCLI
   ```
4. **Appropriate Azure Permissions** - You need permissions to:
   - Create resource groups
   - Create network resources (VNets, NICs, NSGs)
   - Create compute resources (VMs)
   - Create monitoring resources (Log Analytics)

## Deployment Steps

### Step 1: Verify Your Credentials

Update the following variables in `scripts/deploy.ps1`:
```powershell
$subscriptionId = "e0fe32a3-f59a-4e4f-96ea-cbd48502e379"
$tenantId = "9329c02a-4050-4798-93ae-b6e37b19af6d"
$location = "eastus"  # Change if needed
```

### Step 2: Run the Deployment Script

Open PowerShell as Administrator and run:
```powershell
cd "c:\Users\msrini\OneDrive - Microsoft\Desktop\PLS"
.\scripts\deploy.ps1
```

The script will:
1. Connect to Azure
2. Create two resource groups (PLS and PE)
3. Deploy the PLS infrastructure (VNet, Load Balancer, Private Link Service, Log Analytics)
4. Deploy the PE and VM infrastructure (Consumer VNet, 20 Private Endpoints, VM)
5. Display deployment summary with resource details

**Deployment Time:** Approximately 10-15 minutes

### Step 3: Collect Metrics

Once the infrastructure is deployed and stable (wait 10-15 minutes for data to flow), run:
```powershell
.\scripts\collect-metrics.ps1
```

This will:
1. Connect to Azure
2. Retrieve all Private Endpoints in your subscription
3. Fetch bytes in/out metrics for the last 7 days
4. Display results in console and export to CSV

#### Custom Parameters:
```powershell
.\scripts\collect-metrics.ps1 -DaysBack 14 -OutputFile "custom_metrics.csv"
```

## Infrastructure Details

### Resource Groups

#### PLS Resource Group (`rg-pls-prod`)
- **VNet**: 10.0.0.0/16
  - Subnet PLS Frontend: 10.0.1.0/24
  - Subnet PLS Backend: 10.0.2.0/24
- **Load Balancer**: Standard SKU with health probes
- **Private Link Service**: Auto-approved for your subscription
- **Log Analytics Workspace**: For monitoring and diagnostics

#### PE Resource Group (`rg-pe-prod`)
- **VNet**: 10.1.0.0/16
  - Subnet VM: 10.1.0.0/24
  - Subnet PE: 10.1.1.0/24
- **Virtual Machine**: Standard_D2s_v3 (Ubuntu 18.04 LTS)
- **20 Private Endpoints**: Connected to the PLS
- **Public IP**: Attached to VM for remote access
- **Azure Monitor Agent**: For guest-level diagnostics

## Accessing the VM

After deployment, you can access the VM using:

**SSH (Linux)**:
```bash
ssh azureuser@<VM_PUBLIC_IP>
# Retrieve from deployment output or Azure Portal
```

**RDP (Windows Remote Desktop)**:
- Use RDP client to connect to the public IP
- Default username: `azureuser`
- You may need to set a password or use key-based auth

## Monitoring

### View Metrics in Azure Portal

1. Navigate to the **Log Analytics Workspace** in the PE resource group
2. Use **Logs** to query:
   ```kusto
   InsightsMetrics
   | where Namespace == "prometheus"
   | where Name contains "bytes"
   | summarize sum(Val) by Computer, Name
   ```

### Metrics Available
- **BytesIn**: Bytes received by the Private Endpoint
- **BytesOut**: Bytes sent from the Private Endpoint
- CPU, Memory, Network metrics from the VM

## Troubleshooting

### Deployment Fails
- Verify your Azure credentials and subscription access
- Ensure the location is supported for all resource types
- Check resource quotas in your subscription

### Private Endpoints Not Connected
- Wait 5-10 minutes after deployment
- Verify the PLS is in "Active" state in the portal
- Check NSG rules on both VNets

### No Metrics Data
- Ensure 10-15 minutes have passed since deployment
- Verify the VM is sending traffic through the PEs
- Check Log Analytics workspace permissions

## Cleanup

To remove all resources:
```powershell
Remove-AzResourceGroup -Name "rg-pls-prod" -Force
Remove-AzResourceGroup -Name "rg-pe-prod" -Force
```

## File Structure

```
PLS/
├── infrastructure/
│   ├── pls.bicep              # PLS infrastructure template
│   └── pes-vm.bicep           # PE and VM infrastructure template
├── scripts/
│   ├── deploy.ps1             # Main deployment script
│   ├── collect-metrics.ps1    # Metrics collection script
│   └── README.md              # This file
└── requirement.txt            # Project requirements
```

## Support

For issues or questions:
1. Check Azure Portal for resource status
2. Review deployment logs in PowerShell output
3. Check Network Watcher for connectivity issues
4. Review Log Analytics for diagnostic data

---

**Last Updated**: December 8, 2025

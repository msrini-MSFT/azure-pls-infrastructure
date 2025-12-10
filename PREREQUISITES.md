# Prerequisites

## System Requirements

### Operating System
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or higher (PowerShell 7+ recommended)

### Required Software

#### 1. Azure PowerShell Module
Install the latest Azure PowerShell module:

```powershell
# Run as Administrator
Install-Module -Name Az -Force -AllowClobber
```

Verify installation:
```powershell
Get-Module -ListAvailable Az.Accounts
```

#### 2. Azure CLI (Optional but Recommended)
For Bicep template validation:

```powershell
# Using Windows Package Manager
winget install Microsoft.AzureCLI

# Or using Chocolatey
choco install azure-cli
```

Verify installation:
```powershell
az version
```

### Azure Account & Permissions

You must have:

1. **Active Azure Subscription**
   - Test access: `Connect-AzAccount`

2. **Required Azure Roles**
   - `Contributor` or equivalent on the subscription
   - Permissions to create:
     - Resource Groups
     - Virtual Networks & Subnets
     - Network Interfaces & Security Groups
     - Virtual Machines
     - Private Endpoints & Private Link Services
     - Load Balancers
     - Log Analytics Workspaces
     - Public IP Addresses

3. **Service Principal (Optional)**
   - For automated deployments, create a service principal with the above roles

### Network Requirements

- **Outbound internet connectivity** from your machine to Azure endpoints
- **No network proxies** blocking PowerShell Azure module connections

### Resource Quotas

Ensure your Azure subscription has sufficient quota for:
- **Compute**: At least 2 vCPUs (for 1 VM with D2s_v3 SKU)
- **Storage**: 50+ GB available in the region
- **Network**: Sufficient IP addresses in subscription (at least /22 CIDR available)
- **Private Endpoints**: At least 20 available quota
- **Load Balancers**: At least 1 available quota

### Cost Estimate

Monthly cost (approximate, varies by region):

| Resource | SKU | Monthly Cost |
|----------|-----|--------------|
| Virtual Machine | Standard_D2s_v3 | ~$100 |
| Load Balancer | Standard | ~$16 |
| Log Analytics | Pay-as-you-go (1 GB/day) | ~$30 |
| Private Endpoints (20) | Standard | ~$6.60 |
| Virtual Network | - | ~$0.35 |
| **Total** | | **~$150/month** |

---

## Setup Instructions

### Step 1: Verify PowerShell Version

```powershell
$PSVersionTable.PSVersion
```

Expected output: Version 5.1 or higher

### Step 2: Install Azure PowerShell

```powershell
# Install or update
Install-Module -Name Az -Force -AllowClobber

# Import the module
Import-Module Az.Accounts
Import-Module Az.Network
Import-Module Az.Compute
Import-Module Az.OperationalInsights
```

### Step 3: Authenticate to Azure

```powershell
# Interactive login
Connect-AzAccount

# Optional: If you have multiple subscriptions
Get-AzSubscription
Set-AzContext -SubscriptionId "your-subscription-id"
```

### Step 4: Verify Permissions

Run this script to verify your account has necessary permissions:

```powershell
$context = Get-AzContext
$subscriptionId = $context.Subscription.Id
$principal = $context.Account.Id

Write-Host "Logged in as: $principal"
Write-Host "Subscription ID: $subscriptionId"
Write-Host "Subscription Name: $($context.Subscription.Name)"

# Check if you can list resource groups (basic test)
Get-AzResourceGroup -ErrorAction Stop | Out-Null
Write-Host "✓ Permission verification passed"
```

### Step 5: Configure Deployment Variables

Edit the deployment configuration:

**File**: `scripts/deploy.ps1`

Update these variables at the top of the script:

```powershell
# Required configuration
$subscriptionId = "e0fe32a3-f59a-4e4f-96ea-cbd48502e379"  # Your subscription ID
$tenantId = "9329c02a-4050-4798-93ae-b6e37b19af6d"       # Your tenant ID
$location = "eastus"                                       # Azure region

# Optional configuration
$resourceGroupPls = "rg-pls-prod"
$resourceGroupPe = "rg-pe-prod"
$plsName = "pls-prod"
$vmName = "vm-pls-consumer"
```

---

## Troubleshooting

### Issue: "The term 'Connect-AzAccount' is not recognized"

**Solution**: Import the Azure module
```powershell
Import-Module Az.Accounts
```

### Issue: "No subscription found in context"

**Solution**: Login and select subscription
```powershell
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

### Issue: "Insufficient permissions" error during deployment

**Solution**: Ensure your account has the Contributor role
```powershell
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id
```

### Issue: Script timeout during deployment

**Solution**: Increase timeout or run with verbose logging
```powershell
$PSDefaultParameterValues['*:OperationTimeoutInMinutes'] = 30
.\scripts\deploy.ps1 -Verbose
```

### Issue: "Resource quota exceeded"

**Solution**: Check and increase quotas in Azure Portal
1. Navigate to Subscriptions → Usage + quotas
2. Filter by resource type
3. Request quota increase if needed

---

## Support & Documentation

- [Azure PowerShell Documentation](https://learn.microsoft.com/powershell/azure)
- [Azure CLI Documentation](https://learn.microsoft.com/cli/azure)
- [Private Link Service Documentation](https://learn.microsoft.com/azure/private-link/private-link-service-overview)
- [Azure Monitor Documentation](https://learn.microsoft.com/azure/azure-monitor)


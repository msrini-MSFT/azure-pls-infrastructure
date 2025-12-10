# Azure PLS and PE Deployment Script
# This script deploys the entire infrastructure for PLS with 20 Private Endpoints

# Set your variables
$subscriptionId = "e0fe32a3-f59a-4e4f-96ea-cbd48502e379"
$tenantId = "9329c02a-4050-4798-93ae-b6e37b19af6d"
$location = "eastus"
$environment = "prod"

# Resource Group names
$plsRgName = "rg-pls-${environment}"
$peRgName = "rg-pe-${environment}"

# Initialize colors for output
$successColor = "Green"
$errorColor = "Red"
$infoColor = "Cyan"

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -ForegroundColor $Color
}

# Connect to Azure
Write-Log "Connecting to Azure subscription..." $infoColor
Connect-AzAccount -TenantId $tenantId -Subscription $subscriptionId
Set-AzContext -SubscriptionId $subscriptionId | Out-Null

Write-Log "Successfully connected to Azure" $successColor
Write-Log "Tenant ID: $tenantId" $infoColor
Write-Log "Subscription ID: $subscriptionId" $infoColor
Write-Log "Location: $location" $infoColor

# Step 1: Create Resource Groups
Write-Log "Creating Resource Groups..." $infoColor

if (-not (Get-AzResourceGroup -Name $plsRgName -ErrorAction SilentlyContinue)) {
    Write-Log "Creating PLS Resource Group: $plsRgName" $infoColor
    New-AzResourceGroup -Name $plsRgName -Location $location | Out-Null
    Write-Log "PLS Resource Group created successfully" $successColor
} else {
    Write-Log "PLS Resource Group already exists: $plsRgName" $infoColor
}

if (-not (Get-AzResourceGroup -Name $peRgName -ErrorAction SilentlyContinue)) {
    Write-Log "Creating PE Resource Group: $peRgName" $infoColor
    New-AzResourceGroup -Name $peRgName -Location $location | Out-Null
    Write-Log "PE Resource Group created successfully" $successColor
} else {
    Write-Log "PE Resource Group already exists: $peRgName" $infoColor
}

# Step 2: Deploy PLS Infrastructure
Write-Log "Deploying PLS Infrastructure..." $infoColor

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$bicepPath = Join-Path $projectDir "infrastructure\pls.bicep"

if (-not (Test-Path $bicepPath)) {
    Write-Log "ERROR: Bicep file not found: $bicepPath" $errorColor
    exit 1
}

$plsDeployment = New-AzResourceGroupDeployment `
    -ResourceGroupName $plsRgName `
    -TemplateFile $bicepPath `
    -location $location `
    -environment $environment `
    -ErrorAction Stop

Write-Log "PLS Infrastructure deployed successfully" $successColor

# Extract PLS details
$plsId = $plsDeployment.Outputs.plsId.Value
$plsName = $plsDeployment.Outputs.plsName.Value
$laWorkspaceId = $plsDeployment.Outputs.logAnalyticsWorkspaceId.Value

Write-Log "PLS ID: $plsId" $infoColor
Write-Log "PLS Name: $plsName" $infoColor
Write-Log "Log Analytics Workspace ID: $laWorkspaceId" $infoColor

# Step 3: Deploy PE and VM Infrastructure
Write-Log "Deploying Private Endpoints and VM Infrastructure..." $infoColor

$bicepPathPE = Join-Path $projectDir "infrastructure\pes-vm.bicep"

if (-not (Test-Path $bicepPathPE)) {
    Write-Log "ERROR: Bicep file not found: $bicepPathPE" $errorColor
    exit 1
}

$peDeployment = New-AzResourceGroupDeployment `
    -ResourceGroupName $peRgName `
    -TemplateFile $bicepPathPE `
    -location $location `
    -environment $environment `
    -plsResourceId $plsId `
    -logAnalyticsWorkspaceId $laWorkspaceId `
    -peCount 20 `
    -ErrorAction Stop

Write-Log "PE and VM Infrastructure deployed successfully" $successColor

# Extract PE details
$vmId = $peDeployment.Outputs.vmId.Value
$vmPublicIp = $peDeployment.Outputs.vmPublicIPAddress.Value
$peCount = $peDeployment.Outputs.privateEndpointCount.Value

Write-Log "VM ID: $vmId" $infoColor
Write-Log "VM Public IP: $vmPublicIp" $infoColor
Write-Log "Private Endpoints Created: $peCount" $infoColor

# Step 4: Wait for Private Link Service to be ready
Write-Log "Waiting for Private Link Service to stabilize..." $infoColor
Start-Sleep -Seconds 30

# Step 5: Get Private Endpoints status
Write-Log "Checking Private Endpoints status..." $infoColor
$pes = Get-AzPrivateEndpoint -ResourceGroupName $peRgName
Write-Log "Total Private Endpoints: $($pes.Count)" $infoColor

foreach ($pe in $pes) {
    $peStatus = $pe.PrivateLinkServiceConnections[0].ProvisioningState
    Write-Log "PE: $($pe.Name) - Status: $peStatus" $infoColor
}

# Step 6: Summary
Write-Log "===================================================" $infoColor
Write-Log "DEPLOYMENT SUMMARY" $successColor
Write-Log "===================================================" $infoColor
Write-Log "PLS Resource Group: $plsRgName" $infoColor
Write-Log "PE Resource Group: $peRgName" $infoColor
Write-Log "Private Link Service: $plsName" $infoColor
Write-Log "VM Public IP: $vmPublicIp" $infoColor
Write-Log "Private Endpoints: $peCount" $infoColor
Write-Log "Log Analytics Workspace ID: $laWorkspaceId" $infoColor
Write-Log "===================================================" $infoColor

Write-Log "Deployment completed successfully!" $successColor

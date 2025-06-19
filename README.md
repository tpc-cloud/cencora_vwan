# Azure Virtual WAN Deployment

This repository contains Terraform configurations and GitHub Actions workflows to deploy and manage Azure Virtual WAN infrastructure. The architecture separates the Virtual WAN core infrastructure from individual hub deployments, allowing for targeted updates and better resource management.

## Architecture Overview

The deployment is split into two distinct workflows:

### 1. Virtual WAN Core (`terraform-virtualwan-core.yml`)
- **Purpose**: Creates the Virtual WAN itself (runs once)
- **Trigger**: Manual workflow dispatch
- **State File**: `prod/vwan-core.tfstate`
- **Resources**: Virtual WAN resource only

### 2. Virtual WAN Hubs (`terraform-virtualwan.yml`)
- **Purpose**: Creates individual hubs within the existing Virtual WAN
- **Trigger**: Automatic on push to main (when hub configs change)
- **State Files**: `prod/hub1.tfstate`, `prod/hub2.tfstate`, etc.
- **Resources**: Virtual Hub, VPN Gateway, ExpressRoute Gateway for specific hub

## Prerequisites

1. Azure subscription
2. GitHub repository
3. Azure Service Principal with appropriate permissions

## Setup Instructions

1. Create an Azure Service Principal and configure OIDC authentication:

```bash
# Create Azure AD Application
az ad app create --display-name "GitHub-Actions-vWAN"

# Create Service Principal
az ad sp create-for-rbac --name "github-actions-vwan" --role "Contributor" --scopes /subscriptions/<subscription-id>

# Create credential.json file
cat > credential.json << EOF
{
  "name": "github-vwan-actions",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:tpc-cloud/cencora_vwan:ref:refs/heads/main",
  "description": "GitHub Actions OIDC for Virtual WAN",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
EOF

# Create Federated Credential
az ad app federated-credential create \
  --id <app-id> \
  --parameters credential.json
```

2. Add the following secrets to your GitHub repository:
   - `AZURE_CLIENT_ID`: Service Principal Client ID
   - `AZURE_TENANT_ID`: Azure Tenant ID
   - `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID

3. The Terraform state storage account will be created automatically by the workflows.

## Configuration

The Virtual WAN configuration is organized with one hub per file in the `terraform/config/hubs` directory. Each hub has its own YAML configuration file that defines its settings and associated gateways.

### Hub Configuration Structure

Each hub configuration file (e.g., `hub1.yaml`) follows this structure:

```yaml
name: "hub1-${environment}"
address_prefix: "10.0.0.0/24"
sku: "Standard"
hub_routing_preference: "ASPath"
vpn_gateway:
  name: "vpngw1-${environment}"
  scale_unit: 1
express_route_gateway:
  name: "ergw1-${environment}"
  scale_unit: 1
```

### Configuration Parameters

- `name`: Hub name (supports environment variable substitution)
- `address_prefix`: CIDR block for the hub
- `sku`: Hub SKU (Standard)
- `hub_routing_preference`: Routing preference (ASPath, ExpressRoute, VpnGateway)
- `vpn_gateway`: VPN Gateway configuration (optional)
  - `name`: Gateway name
  - `scale_unit`: Gateway scale unit
- `express_route_gateway`: ExpressRoute Gateway configuration (optional)
  - `name`: Gateway name
  - `scale_unit`: Gateway scale unit

## Infrastructure Components

The configuration deploys a comprehensive Virtual WAN setup with:

### Virtual WAN Core
- Single Virtual WAN resource per environment
- Standard SKU
- Centralized management

### Virtual Hubs
- **Hub 1 (ASPath)**
  - Address Space: 10.0.0.0/24
  - Associated VPN Gateway
  - Associated ExpressRoute Gateway
  - ASPath routing preference

- **Hub 2 (ExpressRoute)**
  - Address Space: 10.1.0.0/24
  - Associated VPN Gateway
  - Associated ExpressRoute Gateway
  - ExpressRoute routing preference

- **Hub 3 (VPN)**
  - Address Space: 10.2.0.0/24
  - Associated VPN Gateway
  - VPN Gateway routing preference

- **Hub 4 (ASPath)**
  - Address Space: 10.3.0.0/24
  - Associated VPN Gateway
  - ASPath routing preference

### Gateways
- VPN Gateways for each hub
- ExpressRoute Gateways for Hub 1 and Hub 2
- Standard SKU for all gateways
- Scale units configured for each gateway

### Routing Preferences
- ASPath: Optimized for general routing
- ExpressRoute: Optimized for ExpressRoute connections
- VPNGateway: Optimized for VPN connections

## Deployment Process

### Initial Setup

1. **Deploy Virtual WAN Core**:
   - Go to Actions → "Terraform Virtual WAN Core"
   - Click "Run workflow"
   - Select environment (prod, dev, test)
   - Click "Run workflow"
   - This creates the Virtual WAN infrastructure

2. **Deploy Hubs**:
   - Modify hub configuration files in `terraform/config/hubs/`
   - Push changes to main branch
   - The hub workflow will automatically run and deploy only the changed hubs

### Importing Existing Resources

If you have existing Azure resources that were created outside of Terraform, the workflows will automatically attempt to import them. However, if you need to manually import resources, you can use the provided script:

```bash
# Make sure you're in the terraform directory
cd terraform

# Run the import script
../scripts/import-existing-resources.sh prod <your-subscription-id>
```

The script will:
- Check for existing resource groups
- Check for existing Virtual WAN resources
- Check for existing Virtual Hubs
- Import any found resources into Terraform state

### Ongoing Management

1. **Adding a new hub**:
   - Create a new YAML file in `terraform/config/hubs/`
   - Follow the configuration structure
   - Push to main branch
   - Only the new hub will be deployed

2. **Modifying existing hubs**:
   - Edit the corresponding YAML file
   - Push to main branch
   - Only the modified hub will be updated

3. **Removing a hub**:
   - Delete the corresponding YAML file
   - Push to main branch
   - The hub will be destroyed

## Workflow Details

### Virtual WAN Core Workflow
- **Trigger**: Manual (workflow_dispatch)
- **Purpose**: Create Virtual WAN infrastructure
- **State**: `prod/vwan-core.tfstate`
- **Frequency**: Run once per environment

### Virtual WAN Hubs Workflow
- **Trigger**: Automatic on push to main
- **Purpose**: Deploy individual hubs
- **State**: Separate state files per hub (`prod/hub1.tfstate`, etc.)
- **Intelligence**: Only processes changed hub configurations

## Benefits

- ✅ **Virtual WAN created once**: No duplicate Virtual WAN resources
- ✅ **Individual hub management**: Each hub is managed independently
- ✅ **Targeted deployments**: Only process changed hub configurations
- ✅ **Separate state files**: Each hub has its own state for isolation
- ✅ **Clear separation**: Core infrastructure vs. hub infrastructure
- ✅ **Faster deployments**: Only update what changed
- ✅ **Reduced risk**: Changes to one hub don't affect others

## Customization

You can customize the deployment by modifying the hub configuration files:

1. **Adding a new hub**:
   - Create a new YAML file in `terraform/config/hubs/`
   - Follow the configuration structure
   - The hub will be automatically included in the deployment

2. **Modifying existing hubs**:
   - Edit the corresponding YAML file
   - Update settings as needed
   - Changes will be applied on next deployment

3. **Removing a hub**:
   - Delete the corresponding YAML file
   - The hub will be removed on next deployment

4. **Environment-specific settings**:
   - Use ${environment} variable in names
   - Configure different settings per environment

## Destroy Infrastructure

To destroy the infrastructure, use the destroy workflow:

1. Go to Actions → "Terraform Virtual WAN Destroy"
2. Click "Run workflow"
3. Select the environment to destroy
4. Click "Run workflow"

**Warning**: This will destroy all Virtual WAN infrastructure for the selected environment.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT 
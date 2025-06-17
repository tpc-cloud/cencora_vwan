# Azure Virtual WAN Deployment

This repository contains Terraform configurations and GitHub Actions workflows to deploy and manage Azure Virtual WAN infrastructure using the Azure Verified Module. The configuration supports multiple Virtual Hubs with different routing preferences and associated gateways.

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
  "subject": "repo:tpc-cloud/cencora_vwan:environment:production",
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

3. Create the Azure Storage Account for Terraform state:

```bash
# Create Resource Group
az group create --name terraform-state-rg --location eastus

# Create Storage Account
az storage account create \
  --name tfstate<random-string> \
  --resource-group terraform-state-rg \
  --location eastus \
  --sku Standard_LRS \
  --encryption-services blob

# Create Container
az storage container create \
  --name tfstate \
  --account-name tfstate<random-string>
```

## Testing the Azure Login Configuration

To verify that the Azure login is properly configured:

1. Verify the application exists:
```bash
# List applications
az ad app list --display-name "GitHub-Actions-vWAN" --query "[].{id:appId, name:displayName}" -o table

# Get application details
az ad app show --id <app-id>
```

2. Verify the service principal:
```bash
# List service principals
az ad sp list --display-name "GitHub-Actions-vWAN" --query "[].{id:appId, name:displayName}" -o table
```

3. Verify the federated credential:
```bash
# List federated credentials
az ad app federated-credential list --id <app-id>
```

4. Verify role assignments:
```bash
# List role assignments
az role assignment list --assignee <app-id> --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

5. Test the login:
```bash
# Test service principal login
az login --service-principal \
  --username <app-id> \
  --tenant <tenant-id> \
  --password <client-secret>
```

If you encounter any issues:
1. Ensure the application is created in the correct tenant
2. Verify the federated credential subject matches your repository and environment
3. Check that the service principal has the correct role assignments
4. Confirm all required secrets are set in GitHub

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

## Usage

1. The GitHub Actions workflow will automatically run on:
   - Push to main branch
   - Pull requests to main branch
   - Changes to terraform/** files

2. The workflow will:
   - Format and validate Terraform code
   - Plan changes on pull requests
   - Apply changes when merged to main

3. To deploy changes:
   - Create a new branch
   - Make your changes
   - Create a pull request
   - Review the plan output in the PR
   - Merge to main to apply changes

## Customization

You can customize the deployment by modifying the hub configuration files:

1. Adding a new hub:
   - Create a new YAML file in `terraform/config/hubs/`
   - Follow the configuration structure
   - The hub will be automatically included in the deployment

2. Modifying existing hubs:
   - Edit the corresponding YAML file
   - Update settings as needed
   - Changes will be applied on next deployment

3. Removing a hub:
   - Delete the corresponding YAML file
   - The hub will be removed on next deployment

4. Environment-specific settings:
   - Use ${environment} variable in names
   - Configure different settings per environment

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT 
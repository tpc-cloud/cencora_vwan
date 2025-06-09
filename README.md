# Azure Virtual WAN Deployment

This repository contains Terraform configurations and GitHub Actions workflows to deploy and manage Azure Virtual WAN infrastructure using the Azure Verified Module. The configuration supports multiple Virtual Hubs with different routing preferences and associated gateways.

## Prerequisites

1. Azure subscription
2. GitHub repository
3. Azure Service Principal with appropriate permissions

## Setup Instructions

1. Create an Azure Service Principal and configure OIDC authentication:

```bash
# Create Service Principal
az ad sp create-for-rbac --name "github-actions-vwan" --role "Contributor" --scopes /subscriptions/<subscription-id>

# Create Federated Credential
az ad app federated-credential create \
  --id <app-id> \
  --name "github-actions" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:<github-org>/<repo-name>:ref:refs/heads/main" \
  --audience "api://AzureADTokenExchange"
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

## Configuration

The Virtual WAN configuration is stored in `terraform/config/virtualwan.json`. This file contains all the hub and gateway configurations in a structured format.

### JSON Configuration Structure

```json
{
  "virtual_hubs": {
    "hub_key": {
      "name": "hub-name-${environment}",
      "address_prefix": "10.0.0.0/24",
      "sku": "Standard",
      "hub_routing_preference": "ASPath",
      "vpn_gateway": {
        "name": "vpngw-name-${environment}",
        "scale_unit": 1
      },
      "express_route_gateway": {
        "name": "ergw-name-${environment}",
        "scale_unit": 1
      }
    }
  }
}
```

### Configuration Parameters

- `hub_key`: Unique identifier for the hub
- `name`: Hub name (supports environment variable substitution)
- `address_prefix`: CIDR block for the hub
- `sku`: Hub SKU (Standard)
- `hub_routing_preference`: Routing preference (ASPath, ExpressRoute, VpnGateway)
- `vpn_gateway`: VPN Gateway configuration (optional)
- `express_route_gateway`: ExpressRoute Gateway configuration (optional)

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

You can customize the deployment by modifying the `terraform/config/virtualwan.json` file:

1. Virtual Hub configurations:
   - Add or remove hubs
   - Modify address spaces
   - Change routing preferences
   - Update SKU settings

2. Gateway configurations:
   - Add or remove gateways
   - Modify scale units
   - Change gateway types
   - Update hub associations

3. Environment-specific settings:
   - Use ${environment} variable in names
   - Configure different settings per environment

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT 
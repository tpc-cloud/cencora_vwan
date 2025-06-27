# Azure Virtual WAN Infrastructure with Terraform

This repository contains Terraform configurations for deploying and managing Azure Virtual WAN infrastructure with multiple hubs, firewall rules, and related resources.

## Architecture Overview

The Virtual WAN infrastructure consists of:

- **Virtual WAN Core**: Central hub with Azure Firewall for security
- **Virtual Hubs**: Regional hubs for connecting branch offices, VNets, and remote users
- **VPN Gateways**: For site-to-site and point-to-site VPN connections
- **ExpressRoute Gateways**: For private connectivity via ExpressRoute circuits
- **Firewall Rules**: Network and application rules for traffic filtering

## Configuration Structure

The Virtual WAN configuration is organized by environment in the `terraform/config/{environment}/` directory. Each environment has its own `config.yml` file that defines:

- Environment settings (name, region)
- Virtual WAN core configuration
- Hub configurations with enabled/disabled status
- Firewall rules
- Deployment settings

### Environment Configuration Files

- `terraform/config/prod/config.yml` - Production environment
- `terraform/config/dev/config.yml` - Development environment  
- `terraform/config/staging/config.yml` - Staging environment

Each config file controls what gets deployed and updated in that specific environment.

## Prerequisites

- Azure CLI installed and authenticated
- Terraform 1.0.0 or later
- Azure subscription with appropriate permissions
- GitHub repository with configured secrets

### Required Azure Secrets

Configure these secrets in your GitHub repository:

- `AZURE_CLIENT_ID` - Service Principal Client ID
- `AZURE_TENANT_ID` - Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure Subscription ID

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd Cencora_vwans
```

### 2. Create Resource Groups

Before deploying infrastructure, create the required resource groups for each environment:

```bash
# Create Terraform state resource group (required for all workflows)
./scripts/manage-resource-groups.sh create tf-state eastus

# Create resource groups for all environments
./scripts/manage-resource-groups.sh create prod eastus
./scripts/manage-resource-groups.sh create dev eastus
./scripts/manage-resource-groups.sh create staging eastus

# Or create them one by one
./scripts/manage-resource-groups.sh create prod
./scripts/manage-resource-groups.sh create dev
./scripts/manage-resource-groups.sh create staging
```

### 3. Configure Environment

Edit the appropriate environment config file:

```bash
# For production
vim terraform/config/prod/config.yml

# For development
vim terraform/config/dev/config.yml

# For staging
vim terraform/config/staging/config.yml
```

### 4. Deploy Infrastructure

The infrastructure is deployed automatically via GitHub Actions when you:

- Push changes to the `main` branch (applies changes)
- Create a pull request (runs plan and comments results)

## Resource Group Management

The infrastructure uses separate resource groups for each environment. Resource groups are managed using the provided script and should be created before deploying infrastructure.

### Resource Group Naming Convention

- **Production**: `rg-vwan-prod`
- **Development**: `rg-vwan-dev`
- **Staging**: `rg-vwan-staging`
- **Terraform State**: `rg-tf-state`

### Managing Resource Groups

Use the `scripts/manage-resource-groups.sh` script to manage resource groups:

```bash
# Create resource groups for environments
./scripts/manage-resource-groups.sh create prod eastus
./scripts/manage-resource-groups.sh create dev
./scripts/manage-resource-groups.sh create staging

# Create Terraform state resource group
./scripts/manage-resource-groups.sh create tf-state eastus

# Check if resource groups exist
./scripts/manage-resource-groups.sh exists prod
./scripts/manage-resource-groups.sh exists tf-state

# Show resource group details
./scripts/manage-resource-groups.sh show prod
./scripts/manage-resource-groups.sh show tf-state

# List all resource groups
./scripts/manage-resource-groups.sh list

# Delete resource groups (WARNING: This deletes ALL resources!)
./scripts/manage-resource-groups.sh delete prod
./scripts/manage-resource-groups.sh delete tf-state
```

### Resource Group Requirements

- **Environment Resource Groups** (`rg-vwan-{env}`): Must exist before running Terraform for VWAN infrastructure
- **Terraform State Resource Group** (`rg-tf-state`): Must exist before running any Terraform workflows
- Each environment has its own resource group
- Resource groups are created in the specified Azure region
- The script checks for existing resource groups before creating new ones

### Troubleshooting Resource Groups

If you encounter resource group errors:

1. **Check if resource group exists**:
   ```bash
   ./scripts/manage-resource-groups.sh exists <environment>
   ```

2. **Create missing resource group**:
   ```bash
   ./scripts/manage-resource-groups.sh create <environment>
   ```

3. **Verify resource group details**:
   ```bash
   ./scripts/manage-resource-groups.sh show <environment>
   ```

## Configuration Guide

### Environment Settings

```yaml
environment: prod
region: eastus
```

### Virtual WAN Core Configuration

```yaml
vwan_core:
  enabled: true
  name: "vwan-prod"
  resource_group: "rg-vwan-prod"
  type: "Standard"
  location: "eastus"
  
  firewall:
    enabled: true
    name: "fw-prod"
    policy_name: "fw-policy-prod"
    sku: "Standard"
    public_ip_name: "pip-fw-prod"
    vnet_name: "vnet-fw-prod"
    vnet_address_space: "10.0.0.0/16"
    firewall_subnet: "10.0.1.0/26"
    management_subnet: "10.0.2.0/26"
```

### Hub Configuration

```yaml
hubs:
  hub1:
    enabled: true
    name: "hub1-prod"
    address_prefix: "192.168.0.0/16"
    sku: "Standard"
    hub_routing_preference: "ASPath"
    location: "eastus"
    
    vpn_gateway:
      enabled: true
      name: "vpngw1-prod"
      scale_unit: 1
    
    express_route_gateway:
      enabled: true
      name: "ergw1-prod"
      scale_unit: 1
```

### Firewall Rules

```yaml
firewall_rules:
  enabled: true
  
  network_rules:
    - name: "allow-https"
      protocol: "Https"
      source_addresses: ["*"]
      destination_addresses: ["*"]
      destination_ports: ["443"]
      action: "Allow"
      priority: 100
```

### Spoke VNet Configuration

Spoke VNets are application and workload networks that connect to Virtual WAN hubs. Configure them in the `spoke_vnets` section:

```yaml
spoke_vnets:
  app-vnet:
    enabled: true
    name: "vnet-app-prod"
    type: "application"
    address_space: "172.16.0.0/16"
    hub_connection: "hub1-prod"
    internet_security_enabled: true
    
    subnets:
      - name: "app-subnet"
        address_prefix: "172.16.1.0/24"
        delegation: null
      - name: "db-subnet"
        address_prefix: "172.16.2.0/24"
        delegation: null
    
    network_security_group:
      subnet_name: "app-subnet"
      rules:
        - name: "allow-https"
          priority: 100
          direction: "Inbound"
          access: "Allow"
          protocol: "Tcp"
          source_port_range: "*"
          destination_port_range: "443"
          source_address_prefix: "*"
          destination_address_prefix: "*"
```

**Configuration Options**:
- `enabled`: Enable/disable the spoke VNet
- `name`: VNet name (e.g., "vnet-app-prod")
- `type`: VNet type (e.g., "application", "data", "development")
- `address_space`: VNet address space (e.g., "172.16.0.0/16")
- `hub_connection`: Hub to connect to (must match hub name)
- `internet_security_enabled`: Enable/disable internet security
- `subnets`: List of subnets with address prefixes
- `network_security_group`: Optional NSG configuration

## Infrastructure Components

This project manages the following Azure infrastructure components:

### 1. Virtual WAN Core
- **Virtual WAN**: Central networking hub for connecting multiple locations
- **Azure Firewall**: Centralized network security with policy-based rules
- **Firewall VNet**: Dedicated virtual network for the Azure Firewall
- **Resource Group**: `rg-vwan-{environment}`

### 2. Virtual WAN Hubs
- **Virtual Hubs**: Regional hubs for connecting VNets and on-premises networks
- **VPN Gateways**: For site-to-site and point-to-site VPN connections
- **ExpressRoute Gateways**: For private connections to on-premises networks

### 3. Spoke Virtual Networks
- **Spoke VNets**: Application and workload virtual networks
- **Subnets**: Network segments for different application tiers
- **Network Security Groups**: Traffic filtering rules
- **Hub Connections**: Direct connections to Virtual WAN hubs

## Workflows

The project uses several GitHub Actions workflows to manage different infrastructure components:

### 1. `deploy-network.yml`
- **Purpose**: Main workflow for VWAN core and hub infrastructure
- **Triggers**: Changes to `terraform/config/**/config.yml`
- **Components**: VWAN core, Virtual Hubs, VPN/ExpressRoute Gateways
- **Jobs**: Plan and deploy VWAN core and hub changes

### 2. `deploy-spoke-vnets.yml`
- **Purpose**: Manages spoke virtual networks
- **Triggers**: Changes to `spoke_vnets` section in config files
- **Components**: Spoke VNets, Subnets, NSGs, Hub Connections
- **Jobs**: Plan and deploy spoke VNet changes

### 3. `terraform-virtualwan.yml`
- **Purpose**: Legacy workflow for hub management
- **Status**: Maintained for backward compatibility

### 4. `terraform-virtualwan-core.yml`
- **Purpose**: Legacy workflow for VWAN core management
- **Status**: Maintained for backward compatibility

### 5. `terraform-virtualwan-destroy.yml`
- **Purpose**: Infrastructure destruction workflow
- **Usage**: Manual trigger for cleanup operations

## Managing Infrastructure

### Adding a New Hub

1. Edit the appropriate environment config file
2. Add a new hub configuration under the `hubs` section
3. Set `enabled: true` to deploy it
4. Commit and push changes

Example:
```yaml
hubs:
  hub5:
    enabled: true
    name: "hub5-prod"
    address_prefix: "192.168.4.0/16"
    sku: "Standard"
    hub_routing_preference: "ASPath"
    location: "eastus"
    
    vpn_gateway:
      enabled: false
    
    express_route_gateway:
      enabled: true
      name: "ergw5-prod"
      scale_unit: 1
```

### Modifying Existing Hubs

1. Edit the appropriate environment config file
2. Modify the hub configuration under the `hubs` section
3. Commit and push changes

### Disabling Hubs

1. Edit the appropriate environment config file
2. Set `enabled: false` for the hub you want to disable
3. Commit and push changes

### Updating Firewall Rules

1. Edit the appropriate environment config file
2. Modify the `firewall_rules` section
3. Commit and push changes

## Importing Existing Resources

If you have existing Azure resources that need to be imported into Terraform state:

```bash
# Import resources for production environment
./scripts/import-existing-resources.sh prod <subscription_id>

# Import resources for development environment
./scripts/import-existing-resources.sh dev <subscription_id>
```

## Destroying Infrastructure

To destroy infrastructure for a specific environment:

1. Go to the **Actions** tab in GitHub
2. Select **Terraform Virtual WAN Destroy**
3. Click **Run workflow**
4. Choose the environment to destroy
5. Click **Run workflow**

**Warning**: This will permanently delete all resources in the specified environment.

## Troubleshooting

### Common Issues

1. **State Lock Issues**: The workflows include blob lease breaking to handle state locks
2. **Resource Import Failures**: Check that resources exist and names match exactly
3. **Config File Errors**: Validate YAML syntax in config files

### Debugging

- Check GitHub Actions logs for detailed error messages
- Verify Azure permissions for the service principal
- Ensure config files are properly formatted

## Contributing

1. Create a feature branch
2. Make your changes
3. Test with a pull request (runs plan automatically)
4. Merge to main (applies changes automatically)

## License

This project is licensed under the MIT License. 
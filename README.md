# Azure Virtual WAN Terraform Configuration

This repository contains Terraform configurations for deploying and managing Azure Virtual WAN with multiple hubs. The configuration uses a dynamic approach to create and manage hubs based on YAML configuration files.

## Project Structure

```
.
├── .github/
│   └── workflows/          # GitHub Actions workflows
├── config/
│   └── hubs/              # Hub configuration files
│       ├── hub1.yaml
│       └── hub2.yaml
├── terraform/
│   ├── main.tf            # Main Terraform configuration
│   ├── variables.tf       # Variable definitions
│   ├── outputs.tf         # Output definitions
│   └── backend.tf         # Backend configuration
└── README.md
```

## Prerequisites

- Azure subscription
- Terraform >= 1.0.0
- Azure CLI
- GitHub repository with OIDC authentication configured

## Configuration

### Hub Configuration

Each hub is configured using a YAML file in the `config/hubs` directory. Example configuration:

```yaml
name: "hub1-${environment}"
address_prefix: "10.1.0.0/24"
sku: "Standard"
hub_routing_preference: "ExpressRoute"

vpn_gateway:
  name: "vpngw-hub1-${environment}"
  scale_unit: 1

express_route_gateway:
  name: "ergw-hub1-${environment}"
  scale_unit: 1
```

### Environment Variables

The following variables are used in the configuration:

- `environment`: Environment name (e.g., dev, prod)
- `location`: Azure region for resources (default: eastus)
- `tags`: Tags to apply to all resources

## Usage

### Local Development

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Create a `terraform.tfvars` file with your variables:
   ```hcl
   environment = "dev"
   location    = "eastus"
   tags = {
     Environment = "dev"
     Project     = "vwan"
   }
   ```

3. Plan and apply:
   ```bash
   terraform plan
   terraform apply
   ```

### GitHub Actions

The repository includes GitHub Actions workflows for automated deployment:

1. `terraform.yml`: Main workflow for Terraform operations
   - Uses OIDC authentication
   - Supports plan and apply operations
   - Includes security scanning

2. `azure-ad-app.yml`: Workflow for Azure AD application management
   - Creates/updates Azure AD application
   - Configures OIDC authentication
   - Manages service principal

## Adding a New Hub

To add a new hub:

1. Create a new YAML file in `config/hubs/` (e.g., `hub3.yaml`)
2. Define the hub's configuration following the existing pattern
3. The main Terraform configuration will automatically pick up the new hub

## State Management

Each hub's state is stored in Azure Blob Storage with the following structure:
```
tfstate/
├── hubs/
│   ├── hub1/
│   │   └── terraform.tfstate
│   └── hub2/
│       └── terraform.tfstate
```

## Security

- Uses OIDC authentication for GitHub Actions
- Implements least privilege access
- Includes security scanning in CI/CD pipeline
- Follows Azure security best practices

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
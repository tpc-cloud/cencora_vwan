#!/bin/bash

# Script to manage Azure Resource Groups for Virtual WAN environments
# Usage: ./manage-resource-groups.sh <action> <environment> [location]
# Actions: create, delete, show, list
# Example: ./manage-resource-groups.sh create prod eastus

set -e

ACTION=${1:-""}
ENVIRONMENT=${2:-""}
LOCATION=${3:-"eastus"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <action> <environment> [location]"
    echo ""
    echo "Actions:"
    echo "  create  - Create resource group for environment"
    echo "  delete  - Delete resource group for environment"
    echo "  show    - Show resource group details"
    echo "  list    - List all VWAN resource groups"
    echo "  exists  - Check if resource group exists"
    echo ""
    echo "Environments:"
    echo "  prod, dev, staging"
    echo ""
    echo "Location (optional, default: eastus):"
    echo "  eastus, westus, centralus, etc."
    echo ""
    echo "Examples:"
    echo "  $0 create prod eastus"
    echo "  $0 delete dev"
    echo "  $0 show prod"
    echo "  $0 list"
    echo "  $0 exists staging"
}

# Validate inputs
if [ -z "$ACTION" ] || [ -z "$ENVIRONMENT" ]; then
    if [ "$ACTION" = "list" ]; then
        # List action doesn't need environment
        ENVIRONMENT=""
    else
        print_status $RED "Error: Missing required arguments"
        show_usage
        exit 1
    fi
fi

# Validate action
case $ACTION in
    create|delete|show|exists)
        if [ -z "$ENVIRONMENT" ]; then
            print_status $RED "Error: Environment is required for action '$ACTION'"
            show_usage
            exit 1
        fi
        ;;
    list)
        # List action doesn't need environment validation
        ;;
    *)
        print_status $RED "Error: Invalid action '$ACTION'"
        show_usage
        exit 1
        ;;
esac

# Validate environment (if provided)
if [ -n "$ENVIRONMENT" ]; then
    case $ENVIRONMENT in
        prod|dev|staging)
            # Valid environment
            ;;
        *)
            print_status $RED "Error: Invalid environment '$ENVIRONMENT'. Must be one of: prod, dev, staging"
            show_usage
            exit 1
            ;;
    esac
fi

# Set resource group name
if [ -n "$ENVIRONMENT" ]; then
    RESOURCE_GROUP="rg-vwan-${ENVIRONMENT}"
fi

# Function to check if Azure CLI is available
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        print_status $RED "Error: Azure CLI is not installed or not in PATH"
        exit 1
    fi
}

# Function to check if logged in to Azure
check_azure_login() {
    if ! az account show &> /dev/null; then
        print_status $RED "Error: Not logged in to Azure. Please run 'az login' first"
        exit 1
    fi
}

# Function to get current subscription
get_subscription() {
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    print_status $BLUE "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
}

# Function to create resource group
create_resource_group() {
    print_status $BLUE "Creating resource group: $RESOURCE_GROUP"
    print_status $BLUE "Location: $LOCATION"
    print_status $BLUE "Subscription: $SUBSCRIPTION_NAME"
    
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_status $YELLOW "Resource group '$RESOURCE_GROUP' already exists"
        return 0
    fi
    
    if az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table; then
        print_status $GREEN "Successfully created resource group: $RESOURCE_GROUP"
    else
        print_status $RED "Failed to create resource group: $RESOURCE_GROUP"
        exit 1
    fi
}

# Function to delete resource group
delete_resource_group() {
    print_status $BLUE "Deleting resource group: $RESOURCE_GROUP"
    print_status $YELLOW "Warning: This will delete ALL resources in the resource group!"
    
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_status $YELLOW "Resource group '$RESOURCE_GROUP' does not exist"
        return 0
    fi
    
    # Show resources in the group
    print_status $BLUE "Resources in $RESOURCE_GROUP:"
    az resource list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Type:type}" -o table || echo "No resources found"
    
    read -p "Are you sure you want to delete resource group '$RESOURCE_GROUP'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if az group delete --name "$RESOURCE_GROUP" --yes --no-wait; then
            print_status $GREEN "Resource group deletion initiated: $RESOURCE_GROUP"
            print_status $BLUE "Note: Deletion is running in the background. Use 'az group show' to check status."
        else
            print_status $RED "Failed to delete resource group: $RESOURCE_GROUP"
            exit 1
        fi
    else
        print_status $YELLOW "Deletion cancelled"
    fi
}

# Function to show resource group details
show_resource_group() {
    print_status $BLUE "Resource group details: $RESOURCE_GROUP"
    
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_status $RED "Resource group '$RESOURCE_GROUP' does not exist"
        exit 1
    fi
    
    echo ""
    print_status $BLUE "Basic Information:"
    az group show --name "$RESOURCE_GROUP" --query "{Name:name, Location:location, ProvisioningState:properties.provisioningState, Tags:tags}" -o table
    
    echo ""
    print_status $BLUE "Resources in group:"
    az resource list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Type:type, Location:location, ProvisioningState:properties.provisioningState}" -o table || echo "No resources found"
}

# Function to check if resource group exists
check_resource_group_exists() {
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_status $GREEN "Resource group '$RESOURCE_GROUP' exists"
        exit 0
    else
        print_status $RED "Resource group '$RESOURCE_GROUP' does not exist"
        exit 1
    fi
}

# Function to list all VWAN resource groups
list_resource_groups() {
    print_status $BLUE "Listing all VWAN resource groups:"
    echo ""
    
    # Get all resource groups that match the VWAN pattern
    VWAN_RGS=$(az group list --query "[?contains(name, 'rg-vwan-')].{Name:name, Location:location, ProvisioningState:properties.provisioningState}" -o table)
    
    if [ -n "$VWAN_RGS" ]; then
        echo "$VWAN_RGS"
    else
        print_status $YELLOW "No VWAN resource groups found"
    fi
    
    echo ""
    print_status $BLUE "Resource group naming pattern: rg-vwan-{environment}"
    print_status $BLUE "Expected groups: rg-vwan-prod, rg-vwan-dev, rg-vwan-staging"
}

# Main execution
main() {
    # Check prerequisites
    check_azure_cli
    check_azure_login
    get_subscription
    
    echo ""
    
    # Execute requested action
    case $ACTION in
        create)
            create_resource_group
            ;;
        delete)
            delete_resource_group
            ;;
        show)
            show_resource_group
            ;;
        exists)
            check_resource_group_exists
            ;;
        list)
            list_resource_groups
            ;;
        *)
            print_status $RED "Error: Invalid action '$ACTION'"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main 
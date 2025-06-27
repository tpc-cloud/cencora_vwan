#!/bin/bash

# Azure OIDC Setup Script
# This script sets up federated credentials for GitHub Actions to authenticate with Azure
# using OpenID Connect (OIDC) instead of service principal secrets.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --subscription-id SUBSCRIPTION_ID    Azure subscription ID"
    echo "  -t, --tenant-id TENANT_ID                Azure tenant ID"
    echo "  -r, --resource-group RESOURCE_GROUP      Resource group name (default: rg-github-actions)"
    echo "  -n, --app-name APP_NAME                  App registration name (default: github-actions-oidc)"
    echo "  -o, --org-name ORG_NAME                  GitHub organization name"
    echo "  -p, --repo-name REPO_NAME                GitHub repository name"
    echo "  -e, --environment ENVIRONMENT            Environment name (optional, for environment-specific credentials)"
    echo "  -l, --location LOCATION                  Azure location (default: eastus)"
    echo "  -f, --force                              Force recreation of existing resources"
    echo "  -h, --help                               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s 12345678-1234-1234-1234-123456789012 -t 87654321-4321-4321-4321-210987654321 -o myorg -p myrepo"
    echo "  $0 -s 12345678-1234-1234-1234-123456789012 -t 87654321-4321-4321-4321-210987654321 -o myorg -p myrepo -e prod"
    echo ""
    echo "Required GitHub Secrets to configure:"
    echo "  AZURE_CLIENT_ID: The client ID of the app registration"
    echo "  AZURE_TENANT_ID: Your Azure tenant ID"
    echo "  AZURE_SUBSCRIPTION_ID: Your Azure subscription ID"
}

# Parse command line arguments
SUBSCRIPTION_ID=""
TENANT_ID=""
RESOURCE_GROUP="rg-github-actions"
APP_NAME="github-actions-oidc"
ORG_NAME=""
REPO_NAME=""
ENVIRONMENT=""
LOCATION="eastus"
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--subscription-id)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -t|--tenant-id)
            TENANT_ID="$2"
            shift 2
            ;;
        -r|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -n|--app-name)
            APP_NAME="$2"
            shift 2
            ;;
        -o|--org-name)
            ORG_NAME="$2"
            shift 2
            ;;
        -p|--repo-name)
            REPO_NAME="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SUBSCRIPTION_ID" || -z "$TENANT_ID" || -z "$ORG_NAME" || -z "$REPO_NAME" ]]; then
    print_error "Missing required parameters"
    show_usage
    exit 1
fi

# Check if Azure CLI is installed and authenticated
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Set the subscription
print_status "Setting subscription to: $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"

# Verify the subscription
CURRENT_SUB=$(az account show --query id -o tsv)
if [[ "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]]; then
    print_error "Failed to set subscription. Current subscription: $CURRENT_SUB"
    exit 1
fi

print_success "Successfully set subscription to: $SUBSCRIPTION_ID"

# Create resource group if it doesn't exist
print_status "Creating resource group: $RESOURCE_GROUP"
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    print_success "Created resource group: $RESOURCE_GROUP"
else
    print_status "Resource group already exists: $RESOURCE_GROUP"
fi

# Check if app registration already exists
EXISTING_APP_ID=""
if az ad app list --display-name "$APP_NAME" --query "[].appId" -o tsv &> /dev/null; then
    EXISTING_APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[].appId" -o tsv)
fi

if [[ -n "$EXISTING_APP_ID" && "$FORCE" == false ]]; then
    print_warning "App registration '$APP_NAME' already exists with ID: $EXISTING_APP_ID"
    read -p "Do you want to use the existing app registration? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        APP_ID="$EXISTING_APP_ID"
        print_status "Using existing app registration: $APP_ID"
    else
        print_status "Deleting existing app registration..."
        az ad app delete --id "$EXISTING_APP_ID"
        EXISTING_APP_ID=""
    fi
fi

# Create app registration if it doesn't exist
if [[ -z "$EXISTING_APP_ID" ]]; then
    print_status "Creating app registration: $APP_NAME"
    APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
    print_success "Created app registration with ID: $APP_ID"
else
    APP_ID="$EXISTING_APP_ID"
fi

# Create service principal if it doesn't exist
print_status "Creating service principal for app registration"
SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv 2>/dev/null || az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)
print_success "Service principal ID: $SP_ID"

# Assign Contributor role to the service principal
print_status "Assigning Contributor role to service principal"
az role assignment create \
    --assignee "$APP_ID" \
    --role "Contributor" \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    --output none 2>/dev/null || print_warning "Role assignment may already exist"

# Create federated credentials
print_status "Creating federated credentials for GitHub Actions"

# Base repository credential
REPO_CREDENTIAL_NAME="github-actions-$ORG_NAME-$REPO_NAME"
print_status "Creating repository-level credential: $REPO_CREDENTIAL_NAME"

# Remove existing credential if it exists
az ad app federated-credential delete \
    --id "$APP_ID" \
    --federated-credential-id "$REPO_CREDENTIAL_NAME" \
    --output none 2>/dev/null || true

# Create new credential
az ad app federated-credential create \
    --id "$APP_ID" \
    --parameters "{\"name\":\"$REPO_CREDENTIAL_NAME\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:$ORG_NAME/$REPO_NAME:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}" \
    --output none

print_success "Created repository-level federated credential"

# Create environment-specific credential if environment is specified
if [[ -n "$ENVIRONMENT" ]]; then
    ENV_CREDENTIAL_NAME="github-actions-$ORG_NAME-$REPO_NAME-$ENVIRONMENT"
    print_status "Creating environment-specific credential: $ENV_CREDENTIAL_NAME"
    
    # Remove existing credential if it exists
    az ad app federated-credential delete \
        --id "$APP_ID" \
        --federated-credential-id "$ENV_CREDENTIAL_NAME" \
        --output none 2>/dev/null || true
    
    # Create new credential
    az ad app federated-credential create \
        --id "$APP_ID" \
        --parameters "{\"name\":\"$ENV_CREDENTIAL_NAME\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:$ORG_NAME/$REPO_NAME:environment:$ENVIRONMENT\",\"audiences\":[\"api://AzureADTokenExchange\"]}" \
        --output none
    
    print_success "Created environment-specific federated credential"
fi

# Create pull request credential for plan operations
PR_CREDENTIAL_NAME="github-actions-$ORG_NAME-$REPO_NAME-pr"
print_status "Creating pull request credential: $PR_CREDENTIAL_NAME"

# Remove existing credential if it exists
az ad app federated-credential delete \
    --id "$APP_ID" \
    --federated-credential-id "$PR_CREDENTIAL_NAME" \
    --output none 2>/dev/null || true

# Create new credential
az ad app federated-credential create \
    --id "$APP_ID" \
    --parameters "{\"name\":\"$PR_CREDENTIAL_NAME\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:$ORG_NAME/$REPO_NAME:pull_request\",\"audiences\":[\"api://AzureADTokenExchange\"]}" \
    --output none

print_success "Created pull request federated credential"

# List all federated credentials
print_status "Listing all federated credentials for the app registration:"
az ad app federated-credential list --id "$APP_ID" --query "[].{name:name,subject:subject,issuer:issuer}" -o table

# Display summary
echo ""
print_success "Azure OIDC setup completed successfully!"
echo ""
echo "Summary:"
echo "  App Registration Name: $APP_NAME"
echo "  App Registration ID: $APP_ID"
echo "  Service Principal ID: $SP_ID"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  GitHub Repository: $ORG_NAME/$REPO_NAME"
if [[ -n "$ENVIRONMENT" ]]; then
    echo "  Environment: $ENVIRONMENT"
fi
echo ""
echo "Next steps:"
echo "1. Configure the following secrets in your GitHub repository ($ORG_NAME/$REPO_NAME):"
echo "   - AZURE_CLIENT_ID: $APP_ID"
echo "   - AZURE_TENANT_ID: $TENANT_ID"
echo "   - AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo ""
echo "2. Update your GitHub Actions workflow to use OIDC authentication:"
echo "   - Remove any existing AZURE_CREDENTIALS secret"
echo "   - Ensure your workflow has 'id-token: write' permission"
echo "   - Use the azure/login@v2 action with the secrets above"
echo ""
echo "3. Example workflow configuration:"
echo "   permissions:"
echo "     id-token: write"
echo "     contents: read"
echo "   env:"
echo "     ARM_CLIENT_ID: \${{ secrets.AZURE_CLIENT_ID }}"
echo "     ARM_SUBSCRIPTION_ID: \${{ secrets.AZURE_SUBSCRIPTION_ID }}"
echo "     ARM_TENANT_ID: \${{ secrets.AZURE_TENANT_ID }}"
echo ""
echo "4. For Terraform, ensure your provider configuration uses:"
echo "   provider \"azurerm\" {"
echo "     use_oidc = true"
echo "   }"
echo ""
print_success "Setup complete! Your GitHub Actions can now authenticate with Azure using OIDC." 
#!/bin/bash

# Check if required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <location> <environment>"
    echo "Example: $0 eastus dev"
    exit 1
fi

LOCATION=$1
ENVIRONMENT=$2

# Set variables
RESOURCE_GROUP="rg-vwan-terraform-state"
STORAGE_ACCOUNT="sttfstatecencoraprod"
CONTAINER_NAME="tfstate"

# Create resource group if it doesn't exist
echo "Creating resource group $RESOURCE_GROUP..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Check if storage account already exists
if az storage account show --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
    echo "Storage account $STORAGE_ACCOUNT already exists, skipping creation"
else
    # Create storage account if it doesn't exist
    echo "Creating storage account $STORAGE_ACCOUNT..."
    az storage account create \
        --name $STORAGE_ACCOUNT \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --sku Standard_LRS \
        --encryption-services blob
fi

# Create blob container if it doesn't exist
echo "Creating blob container $CONTAINER_NAME..."
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT

# Get storage account key
echo "Getting storage account key..."
STORAGE_KEY=$(az storage account keys list \
    --account-name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query '[0].value' \
    --output tsv)

echo "Backend storage setup complete!"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo ""
echo "You can now run your Terraform commands with the backend configured." 
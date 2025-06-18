#!/bin/bash

# Check if required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <location> <environment>"
    exit 1
fi

LOCATION=$1
ENVIRONMENT=$2

# Set variables
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="stterraformstate${ENVIRONMENT}"
CONTAINER_NAME="tfstate"

# Create resource group
echo "Creating resource group: $RESOURCE_GROUP"
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION

# Create storage account
echo "Creating storage account: $STORAGE_ACCOUNT"
az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --encryption-services blob

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group $RESOURCE_GROUP \
    --account-name $STORAGE_ACCOUNT \
    --query '[0].value' -o tsv)

# Create blob container
echo "Creating blob container: $CONTAINER_NAME"
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT \
    --account-key $ACCOUNT_KEY

echo "Backend storage setup complete!"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
echo "Resource Group: $RESOURCE_GROUP" 
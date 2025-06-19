#!/bin/bash

# Script to import existing Azure resources into Terraform state
# Usage: ./import-existing-resources.sh <environment> <subscription_id>

set -e

ENVIRONMENT=${1:-prod}
SUBSCRIPTION_ID=${2:-""}

if [ -z "$SUBSCRIPTION_ID" ]; then
    echo "Usage: $0 <environment> <subscription_id>"
    echo "Example: $0 prod 12345678-1234-1234-1234-123456789012"
    exit 1
fi

echo "Importing existing resources for environment: $ENVIRONMENT"
echo "Subscription ID: $SUBSCRIPTION_ID"

# Set Azure context
az account set --subscription "$SUBSCRIPTION_ID"

# Check and import resource group
RESOURCE_GROUP="rg-vwan-$ENVIRONMENT"
echo "Checking resource group: $RESOURCE_GROUP"
if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Importing resource group..."
    terraform import azurerm_resource_group.vwan "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
else
    echo "Resource group $RESOURCE_GROUP does not exist"
fi

# Check and import Virtual WAN
VWAN_NAME="vwan-$ENVIRONMENT"
echo "Checking Virtual WAN: $VWAN_NAME"
if az network vwan show --name "$VWAN_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Importing Virtual WAN..."
    terraform import azurerm_virtual_wan.vwan "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualWans/$VWAN_NAME"
else
    echo "Virtual WAN $VWAN_NAME does not exist"
fi

# Check and import Virtual Hubs
echo "Checking Virtual Hubs..."
for hub_file in terraform/config/hubs/*.yaml; do
    if [ -f "$hub_file" ]; then
        hub_name=$(basename "$hub_file" .yaml)
        hub_display_name=$(grep "name:" "$hub_file" | head -1 | sed 's/.*name: *"\([^"]*\)".*/\1/' | sed "s/\${environment}/$ENVIRONMENT/g")
        
        echo "Checking Virtual Hub: $hub_display_name"
        if az network vhub show --name "$hub_display_name" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
            echo "Importing Virtual Hub: $hub_display_name"
            terraform import "azurerm_virtual_hub.hub" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualHubs/$hub_display_name"
        else
            echo "Virtual Hub $hub_display_name does not exist"
        fi
    fi
done

echo "Import process completed!" 
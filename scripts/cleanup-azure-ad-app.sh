#!/bin/bash

# Check if required arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <app-name>"
    exit 1
fi

APP_NAME=$1

echo "Searching for Azure AD application with name: $APP_NAME"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

if [ -z "$APP_ID" ]; then
    echo "No application found with name: $APP_NAME"
    exit 1
fi

echo "Found application with ID: $APP_ID"

# Get the service principal ID
echo "Getting service principal ID..."
SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)

if [ -z "$SP_ID" ]; then
    echo "No service principal found for application: $APP_NAME"
else
    echo "Found service principal with ID: $SP_ID"
    
    # Remove role assignments
    echo "Removing role assignments..."
    az role assignment list --assignee "$SP_ID" --query "[].id" -o tsv | while read -r assignment_id; do
        if [ ! -z "$assignment_id" ]; then
            echo "Removing role assignment: $assignment_id"
            az role assignment delete --ids "$assignment_id"
        fi
    done

    # Delete the service principal
    echo "Deleting service principal..."
    az ad sp delete --id "$SP_ID"
fi

# Delete the application
echo "Deleting Azure AD application..."
az ad app delete --id "$APP_ID"

echo "Cleanup complete!" 
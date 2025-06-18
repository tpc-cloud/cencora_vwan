#!/bin/bash

# Check if required arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <app-name> <github-org> <github-repo> <environment>"
    exit 1
fi

APP_NAME=$1
GITHUB_ORG=$2
GITHUB_REPO=$3
ENVIRONMENT=$4

# Create Azure AD Application
echo "Creating Azure AD Application..."
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
echo "Application created with ID: $APP_ID"

# Create Service Principal
echo "Creating Service Principal..."
SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
echo "Service Principal created with ID: $SP_ID"

# Create credential.json for OIDC
echo "Creating OIDC credential configuration..."
cat > credential.json << EOF
{
  "name": "github-actions-${ENVIRONMENT}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:${ENVIRONMENT}",
  "description": "GitHub Actions OIDC for ${APP_NAME} in ${ENVIRONMENT}",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
EOF

# Create Federated Credential
echo "Creating Federated Credential..."
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters credential.json

# Assign Contributor role
echo "Assigning Contributor role..."
az role assignment create \
  --assignee "$SP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)"

# Get Tenant ID and Subscription ID
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Output the required GitHub secrets
echo "Add these secrets to your GitHub repository:"
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"

# Cleanup
rm credential.json

echo "Setup complete! Please add the secrets to your GitHub repository." 
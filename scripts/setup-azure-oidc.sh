#!/bin/bash

# Check if required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <app-name> <github-org> <github-repo>"
    exit 1
fi

APP_NAME=$1
GITHUB_ORG=$2
GITHUB_REPO=$3

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
  "name": "github-actions",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main",
  "description": "GitHub Actions OIDC for ${APP_NAME}",
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
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)"

# Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Output the required GitHub secrets
echo "Add these secrets to your GitHub repository:"
echo "CLIENT_ID: $APP_ID"
echo "TENANT_ID: $TENANT_ID"
echo "SUBSCRIPTION_ID: $(az account show --query id -o tsv)"

# Cleanup
rm credential.json

echo "Setup complete! Please add the secrets to your GitHub repository." 
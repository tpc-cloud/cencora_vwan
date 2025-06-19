terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstatedev"
    container_name       = "tfstate"
    key                  = "prod/hub1.tfstate"
    use_oidc             = true
  }
}

# Note: This file serves as a template and will be dynamically updated by the GitHub Actions workflow
# The actual values for storage_account_name and key will be set during the workflow execution 
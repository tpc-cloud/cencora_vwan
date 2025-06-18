terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "terraform_state" {
  name     = "rg-terraform-state"
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "terraform_state" {
  name                     = "stterraformstate${var.environment}"
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version         = "TLS1_2"

  tags = var.tags
}

resource "azurerm_storage_container" "terraform_state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private"
}

# Enable blob encryption
resource "azurerm_storage_account_customer_managed_key" "terraform_state" {
  storage_account_id = azurerm_storage_account.terraform_state.id
  key_vault_id       = azurerm_key_vault.terraform_state.id
  key_name           = azurerm_key_vault_key.terraform_state.name
}

# Create Key Vault for encryption
resource "azurerm_key_vault" "terraform_state" {
  name                        = "kv-terraform-state-${var.environment}"
  location                    = azurerm_resource_group.terraform_state.location
  resource_group_name         = azurerm_resource_group.terraform_state.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                   = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
      "Create",
      "Delete",
      "List",
      "Restore",
      "Recover",
      "UnwrapKey",
      "WrapKey",
      "Purge",
      "Encrypt",
      "Decrypt",
      "Sign",
      "Verify"
    ]
  }

  tags = var.tags
}

# Create Key Vault Key
resource "azurerm_key_vault_key" "terraform_state" {
  name         = "terraform-state-key"
  key_vault_id = azurerm_key_vault.terraform_state.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

# Get current client configuration
data "azurerm_client_config" "current" {} 
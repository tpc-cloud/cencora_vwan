terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatevwan"
    container_name      = "tfstate"
    key                 = "vwan-${var.hub_name}.tfstate"
  }
} 
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
} 
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

data "azurerm_resource_group" "vwan" {
  name = "rg-vwan-${var.environment}"
}

# Create the Virtual WAN without any hubs
resource "azurerm_virtual_wan" "vwan" {
  name                = "vwan-${var.environment}"
  resource_group_name = data.azurerm_resource_group.vwan.name
  location            = var.location
  type                = "Standard"
  tags                = var.tags
} 
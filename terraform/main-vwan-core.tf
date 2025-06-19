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

# Create the resource group for Virtual WAN
resource "azurerm_resource_group" "vwan" {
  name     = "rg-vwan-${var.environment}"
  location = var.location
  tags     = var.tags
}

# Create the Virtual WAN without any hubs
resource "azurerm_virtual_wan" "vwan" {
  name                = "vwan-${var.environment}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = var.location
  type                = "Standard"
  tags                = var.tags
} 
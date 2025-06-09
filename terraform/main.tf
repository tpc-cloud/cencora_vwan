terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate${random_string.suffix.result}"
    container_name       = "tfstate"
    key                  = "virtualwan.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "vwan" {
  name     = "rg-vwan-${var.environment}"
  location = var.location
  tags     = var.tags
}

locals {
  config = jsondecode(replace(file("${path.module}/config/virtualwan.json"), "\${environment}", var.environment))
  
  virtual_hubs = {
    for hub_key, hub in local.config.virtual_hubs : hub_key => {
      name                = hub.name
      resource_group_name = azurerm_resource_group.vwan.name
      location            = var.location
      address_prefix      = hub.address_prefix
      sku                 = hub.sku
      hub_routing_preference = hub.hub_routing_preference
    }
  }

  vpn_gateways = {
    for hub_key, hub in local.config.virtual_hubs : "${hub_key}-vpngw" => {
      name                = hub.vpn_gateway.name
      virtual_hub_key     = hub_key
      resource_group_name = azurerm_resource_group.vwan.name
      location            = var.location
      scale_unit         = hub.vpn_gateway.scale_unit
    }
  }

  express_route_gateways = {
    for hub_key, hub in local.config.virtual_hubs : "${hub_key}-ergw" => {
      name                = hub.express_route_gateway.name
      virtual_hub_key     = hub_key
      resource_group_name = azurerm_resource_group.vwan.name
      location            = var.location
      scale_unit         = hub.express_route_gateway.scale_unit
    } if contains(keys(hub), "express_route_gateway")
  }
}

module "virtual_wan" {
  source  = "Azure/avm-ptn-virtualwan/azurerm"
  version = "0.12.3"

  name                = "vwan-${var.environment}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = var.location

  virtual_hubs = local.virtual_hubs
  vpn_gateways = local.vpn_gateways
  express_route_gateways = local.express_route_gateways

  tags = var.tags
} 
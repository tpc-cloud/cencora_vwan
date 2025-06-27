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

data "azurerm_virtual_wan" "vwan" {
  name                = "vwan-${var.environment}"
  resource_group_name = data.azurerm_resource_group.vwan.name
}

locals {
  # Read the environment-specific config file
  config_file = "../config/${var.environment}/config.yml"
  
  # Read and parse the environment configuration
  config = yamldecode(file(local.config_file))
  
  # Get the specific hub configuration based on hub_name variable
  hub_config = local.config.hubs[var.hub_name]
}

# Create Virtual Hub for the specific hub
resource "azurerm_virtual_hub" "hub" {
  name                   = local.hub_config.name
  resource_group_name    = data.azurerm_resource_group.vwan.name
  location               = var.location
  address_prefix         = local.hub_config.address_prefix
  virtual_wan_id         = data.azurerm_virtual_wan.vwan.id
  sku                    = local.hub_config.sku
  hub_routing_preference = local.hub_config.hub_routing_preference
  tags                   = var.tags
}

# Create VPN Gateway if enabled in hub config
resource "azurerm_vpn_gateway" "vpn_gateway" {
  count               = local.hub_config.vpn_gateway.enabled ? 1 : 0
  name                = local.hub_config.vpn_gateway.name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.vwan.name
  virtual_hub_id      = azurerm_virtual_hub.hub.id
  scale_unit          = local.hub_config.vpn_gateway.scale_unit
  tags                = var.tags
}

# Create ExpressRoute Gateway if enabled in hub config
resource "azurerm_express_route_gateway" "express_route_gateway" {
  count               = local.hub_config.express_route_gateway.enabled ? 1 : 0
  name                = local.hub_config.express_route_gateway.name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.vwan.name
  virtual_hub_id      = azurerm_virtual_hub.hub.id
  scale_units         = local.hub_config.express_route_gateway.scale_unit
  tags                = var.tags
} 
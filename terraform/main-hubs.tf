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
  # Get specific hub configuration file based on hub_name variable
  hub_file = "${var.hub_name}.yaml"

  # Read and parse the specific hub configuration
  hub_config = yamldecode(
    replace(
      file("../config/hubs/${local.hub_file}"),
      "$${environment}",
      var.environment
    )
  )
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

# Create VPN Gateway if specified in hub config
resource "azurerm_vpn_gateway" "vpn_gateway" {
  count               = contains(keys(local.hub_config), "vpn_gateway") ? 1 : 0
  name                = local.hub_config.vpn_gateway.name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.vwan.name
  virtual_hub_id      = azurerm_virtual_hub.hub.id
  scale_unit          = local.hub_config.vpn_gateway.scale_unit
  tags                = var.tags
}

# Create ExpressRoute Gateway if specified in hub config
resource "azurerm_express_route_gateway" "express_route_gateway" {
  count               = contains(keys(local.hub_config), "express_route_gateway") ? 1 : 0
  name                = local.hub_config.express_route_gateway.name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.vwan.name
  virtual_hub_id      = azurerm_virtual_hub.hub.id
  scale_units         = local.hub_config.express_route_gateway.scale_unit
  tags                = var.tags
} 
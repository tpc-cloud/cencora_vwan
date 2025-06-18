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

locals {
  hub_configs = {
    for file in fileset("${path.module}/config/hubs", "*.yaml") :
    trimsuffix(file, ".yaml") => yamldecode(
      replace(
        file("${path.module}/config/hubs/${file}"),
        "\\${environment}",
        var.environment
      )
    )
  }
}

module "virtual_wan" {
  source  = "Azure/avm-ptn-virtualwan/azurerm"
  version = "0.12.3"

  name                = "vwan-${var.environment}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = var.location

  virtual_hubs = {
    for hub_name, config in local.hub_configs :
    hub_name => {
      name                   = config.name
      resource_group_name    = azurerm_resource_group.vwan.name
      location               = var.location
      address_prefix         = config.address_prefix
      sku                    = config.sku
      hub_routing_preference = config.hub_routing_preference
    }
  }

  vpn_gateways = {
    for hub_name, config in local.hub_configs :
    "${hub_name}-vpngw" => {
      name                = config.vpn_gateway.name
      virtual_hub_key     = hub_name
      resource_group_name = azurerm_resource_group.vwan.name
      location            = var.location
      scale_unit          = config.vpn_gateway.scale_unit
    }
  }

  express_route_gateways = {
    for hub_name, config in local.hub_configs :
    "${hub_name}-ergw" => {
      name                = config.express_route_gateway.name
      virtual_hub_key     = hub_name
      resource_group_name = azurerm_resource_group.vwan.name
      location            = var.location
      scale_unit          = config.express_route_gateway.scale_unit
    }
  }

  tags = var.tags
}

resource "azurerm_resource_group" "vwan" {
  name     = "rg-vwan-${var.environment}"
  location = var.location
  tags     = var.tags
} 
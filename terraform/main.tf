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

locals {
  # Get specific hub configuration file based on hub_name variable
  hub_file = "${var.hub_name}.yaml"

  # Read and parse the specific hub configuration
  hub_config = yamldecode(
    replace(
      file("${path.module}/config/hubs/${local.hub_file}"),
      "$${environment}",
      var.environment
    )
  )

  virtual_hubs = {
    "${var.hub_name}" => {
      name                   = local.hub_config.name
      resource_group         = data.azurerm_resource_group.vwan.name
      location               = var.location
      address_prefix         = local.hub_config.address_prefix
      sku                    = local.hub_config.sku
      hub_routing_preference = local.hub_config.hub_routing_preference
    }
  }

  vpn_gateways = {
    "${var.hub_name}-vpngw" => {
      name                = local.hub_config.vpn_gateway.name
      virtual_hub_key     = var.hub_name
      resource_group_name = data.azurerm_resource_group.vwan.name
      location            = var.location
      scale_unit          = local.hub_config.vpn_gateway.scale_unit
    }
  }

  express_route_gateways = contains(keys(local.hub_config), "express_route_gateway") ? {
    "${var.hub_name}-ergw" => {
      name                = local.hub_config.express_route_gateway.name
      virtual_hub_key     = var.hub_name
      resource_group_name = data.azurerm_resource_group.vwan.name
      location            = var.location
      scale_unit          = local.hub_config.express_route_gateway.scale_unit
    }
  } : {}
}

module "virtual_wan" {
  source  = "Azure/avm-ptn-virtualwan/azurerm"
  version = "0.12.3"

  virtual_wan_name    = "vwan-${var.environment}"
  resource_group_name = data.azurerm_resource_group.vwan.name
  location            = var.location

  virtual_hubs          = local.virtual_hubs
  vpn_gateways          = local.vpn_gateways
  expressroute_gateways = local.express_route_gateways

  tags = var.tags
} 
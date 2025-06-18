terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  client_id       = var.client_id
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  use_oidc        = true
}

resource "azurerm_resource_group" "vwan" {
  name     = "rg-vwan-${var.environment}"
  location = var.location
  tags     = var.tags
}

locals {
  # Get all hub configuration files
  hub_files = fileset("${path.module}/config/hubs", "*.yaml")

  # Read and parse each hub configuration
  hub_configs = {
    for hub_file in local.hub_files :
    trimsuffix(hub_file, ".yaml") => yamldecode(
      replace(
        file("${path.module}/config/hubs/${hub_file}"),
        "$${environment}",
        var.environment
      )
    )
  }

  virtual_hubs = {
    for hub_key, hub in local.hub_configs : hub_key => {
      name                   = hub.name
      resource_group_name    = azurerm_resource_group.vwan.name
      location               = var.location
      address_prefix         = hub.address_prefix
      sku                    = hub.sku
      hub_routing_preference = hub.hub_routing_preference
    }
  }

  vpn_gateways = {
    for hub_key, hub in local.hub_configs : "${hub_key}-vpngw" => {
      name                = hub.vpn_gateway.name
      virtual_hub_key     = hub_key
      resource_group_name = azurerm_resource_group.vwan.name
      location            = var.location
      scale_unit          = hub.vpn_gateway.scale_unit
    }
  }

  express_route_gateways = {
    for hub_key, hub in local.hub_configs : "${hub_key}-ergw" => {
      name                = hub.express_route_gateway.name
      virtual_hub_key     = hub_key
      resource_group_name = azurerm_resource_group.vwan.name
      location            = var.location
      scale_unit          = hub.express_route_gateway.scale_unit
    } if contains(keys(hub), "express_route_gateway")
  }
}

module "virtual_wan" {
  source  = "Azure/avm-ptn-virtualwan/azurerm"
  version = "0.12.3"

  name                = "vwan-${var.environment}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = var.location

  virtual_hubs           = local.virtual_hubs
  vpn_gateways           = local.vpn_gateways
  express_route_gateways = local.express_route_gateways

  tags = var.tags
} 
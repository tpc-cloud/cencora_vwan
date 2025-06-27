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
  
  # Get the spoke VNet configuration
  spoke_vnets = local.config.spoke_vnets
}

# Create spoke VNets based on configuration
resource "azurerm_virtual_network" "spoke_vnets" {
  for_each = local.spoke_vnets

  name                = each.value.name
  resource_group_name = data.azurerm_resource_group.vwan.name
  location            = var.location
  address_space       = [each.value.address_space]
  tags = merge(var.tags, {
    "spoke-type" = each.value.type
    "hub-connection" = each.value.hub_connection
  })
}

# Create subnets for each spoke VNet
resource "azurerm_subnet" "spoke_subnets" {
  for_each = {
    for subnet in flatten([
      for vnet_key, vnet in local.spoke_vnets : [
        for subnet in vnet.subnets : {
          vnet_key = vnet_key
          vnet_name = vnet.name
          subnet_key = subnet.name
          subnet = subnet
        }
      ]
    ]) : "${subnet.vnet_key}-${subnet.subnet_key}" => subnet
  }

  name                 = each.value.subnet.name
  resource_group_name  = data.azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.spoke_vnets[each.value.vnet_key].name
  address_prefixes     = [each.value.subnet.address_prefix]
  
  dynamic "delegation" {
    for_each = each.value.subnet.delegation != null ? [each.value.subnet.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}

# Create Virtual WAN connections for spoke VNets
resource "azurerm_virtual_hub_connection" "spoke_connections" {
  for_each = {
    for vnet_key, vnet in local.spoke_vnets : vnet_key => vnet
    if vnet.hub_connection != null
  }

  name                      = "conn-${each.value.name}-to-${each.value.hub_connection}"
  virtual_hub_id            = data.azurerm_virtual_wan.vwan.id
  remote_virtual_network_id = azurerm_virtual_network.spoke_vnets[each.key].id
  internet_security_enabled = each.value.internet_security_enabled
  routing {
    associated_route_table_id = data.azurerm_virtual_wan.vwan.default_route_table_id
    propagated_route_table {
      route_table_ids = [data.azurerm_virtual_wan.vwan.default_route_table_id]
    }
  }
}

# Create Network Security Groups for spoke VNets (if configured)
resource "azurerm_network_security_group" "spoke_nsgs" {
  for_each = {
    for vnet_key, vnet in local.spoke_vnets : vnet_key => vnet
    if vnet.network_security_group != null
  }

  name                = "nsg-${each.value.name}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.vwan.name
  tags                = var.tags
}

# Create NSG rules
resource "azurerm_network_security_rule" "spoke_nsg_rules" {
  for_each = {
    for rule in flatten([
      for vnet_key, vnet in local.spoke_vnets : [
        for rule in vnet.network_security_group.rules : {
          vnet_key = vnet_key
          vnet_name = vnet.name
          rule_key = rule.name
          rule = rule
        }
      ] if vnet.network_security_group != null
    ]) : "${rule.vnet_key}-${rule.rule_key}" => rule
  }

  name                        = each.value.rule.name
  priority                    = each.value.rule.priority
  direction                   = each.value.rule.direction
  access                      = each.value.rule.access
  protocol                    = each.value.rule.protocol
  source_port_range           = each.value.rule.source_port_range
  destination_port_range      = each.value.rule.destination_port_range
  source_address_prefix       = each.value.rule.source_address_prefix
  destination_address_prefix  = each.value.rule.destination_address_prefix
  resource_group_name         = data.azurerm_resource_group.vwan.name
  network_security_group_name = azurerm_network_security_group.spoke_nsgs[each.value.vnet_key].name
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "spoke_nsg_associations" {
  for_each = {
    for vnet_key, vnet in local.spoke_vnets : vnet_key => vnet
    if vnet.network_security_group != null
  }

  subnet_id                 = azurerm_subnet.spoke_subnets["${each.key}-${each.value.network_security_group.subnet_name}"].id
  network_security_group_id = azurerm_network_security_group.spoke_nsgs[each.key].id
} 
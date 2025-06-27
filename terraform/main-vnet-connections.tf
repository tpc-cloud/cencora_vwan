locals {
  conn_files = fileset("${path.module}/../config/vnet_connections", "*.yaml")
}

data "azurerm_virtual_hub" "hubs" {
  for_each = toset([for f in local.conn_files : yamldecode(file("../config/vnet_connections/${f}")).virtual_hub_name])
  name                = each.value
  resource_group_name = "rg-vwan-${var.environment}"
}

resource "azurerm_virtual_hub_connection" "connections" {
  for_each = {
    for file in local.conn_files : file => yamldecode(file("../config/vnet_connections/${file}"))
  }

  name                      = each.value.name
  virtual_hub_id            = data.azurerm_virtual_hub.hubs[each.value.virtual_hub_name].id
  remote_virtual_network_id = each.value.remote_vnet_id
  internet_security_enabled = each.value.internet_security_enabled
  tags                      = var.tags
}
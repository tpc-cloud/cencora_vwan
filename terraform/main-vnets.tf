locals {
  vnet_files = fileset("${path.module}/../config/vnets", "*.yaml")
}

resource "azurerm_virtual_network" "vnets" {
  for_each = {
    for file in local.vnet_files : file => yamldecode(file("../config/vnets/${file}"))
  }

  name                = each.value.name
  address_space       = [each.value.address_space]
  location            = each.value.location
  resource_group_name = each.value.resource_group
  tags                = var.tags
}
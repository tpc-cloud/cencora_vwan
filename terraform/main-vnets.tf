locals {
  # Load VNet YAML
  vnet_file = "${var.vnet_name}.yaml"
  vnet_config = yamldecode(
    replace(
      file("../config/vnets/${local.vnet_file}"),
      "$${environment}",
      var.environment
    )
  )

  # Load VNet Connection YAML
  vnet_conn_file = "vnetconn-${var.vnet_name}.yaml"
  vnet_conn_config = yamldecode(
    replace(
      file("../config/vnet_connections/${local.vnet_conn_file}"),
      "$${environment}",
      var.environment
    )
  )
}

# Reference Virtual Hub from connection config
data "azurerm_virtual_hub" "vhub" {
  name                = local.vnet_conn_config.vhub_name
  resource_group_name = data.azurerm_resource_group.vwan.name
}

# Create the VNet
resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_config.name
  address_space       = [local.vnet_config.address_prefix]
  location            = var.location
  resource_group_name = data.azurerm_resource_group.vwan.name
  tags                = var.tags
}

# Create subnets
resource "azurerm_subnet" "subnets" {
  for_each = {
    for subnet in local.vnet_config.subnets : subnet.name => subnet
  }

  name                 = each.value.name
  address_prefixes     = [each.value.prefix]
  resource_group_name  = data.azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

# Create VNet-to-Hub connection
resource "azurerm_virtual_hub_connection" "vnet_connection" {
  name                      = local.vnet_conn_config.name
  virtual_hub_id            = data.azurerm_virtual_hub.vhub.id
  remote_virtual_network_id = azurerm_virtual_network.vnet.id
  internet_security_enabled = local.vnet_conn_config.enable_internet_security
  tags                      = var.tags

  routing {
    associated_route_table_id = null

    propagated_route_table {
      labels = local.vnet_conn_config.routing_configuration.propagated_route_tables
      route_table_ids = [
        "${data.azurerm_virtual_hub.vhub.id}/hubRouteTables/default"
      ]
    }
  }
}

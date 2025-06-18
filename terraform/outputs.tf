output "virtual_hubs" {
  description = "Map of Virtual Hub IDs"
  value = {
    for hub_name, hub in module.virtual_wan.virtual_hubs :
    hub_name => hub.id
  }
}

output "vpn_gateways" {
  description = "Map of VPN Gateway IDs"
  value = {
    for gw_name, gw in module.virtual_wan.vpn_gateways :
    gw_name => gw.id
  }
}

output "express_route_gateways" {
  description = "Map of ExpressRoute Gateway IDs"
  value = {
    for gw_name, gw in module.virtual_wan.express_route_gateways :
    gw_name => gw.id
  }
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.vwan.name
} 
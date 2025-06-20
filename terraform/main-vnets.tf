locals {
  vnet_files = fileset("${path.module}/config/vnets", "*.yaml")

  vnet_configs = {
    for file in local.customer_files :
    trimsuffix(file, ".yaml") => yamldecode(file("${path.module}/config/vnets/${file}"))
  }
}
 

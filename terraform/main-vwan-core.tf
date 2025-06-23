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

# Create the resource group for Virtual WAN
resource "azurerm_resource_group" "vwan" {
  name     = "rg-vwan-${var.environment}"
  location = var.location
  tags     = var.tags
}

# Create the Virtual WAN without any hubs
resource "azurerm_virtual_wan" "vwan" {
  name                = "vwan-${var.environment}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = var.location
  type                = "Standard"
  tags                = var.tags
}

# Create Azure Firewall Policy
resource "azurerm_firewall_policy" "vwan" {
  name                = "fw-policy-${var.environment}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = var.location
  tags                = var.tags
}

# Create Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "pip-fw-${var.environment}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Create Azure Firewall
resource "azurerm_firewall" "vwan" {
  name                = "fw-${var.environment}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = var.location
  firewall_policy_id  = azurerm_firewall_policy.vwan.id
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "firewall-ip-config"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# Create Virtual Network for Firewall
resource "azurerm_virtual_network" "firewall" {
  name                = "vnet-fw-${var.environment}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

# Create Subnet for Firewall
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.firewall.name
  address_prefixes     = ["10.0.1.0/26"]
}

# Create Management Subnet for Firewall (if using Premium SKU)
resource "azurerm_subnet" "firewall_management" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.firewall.name
  address_prefixes     = ["10.0.2.0/26"]
}

# Create Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "vwan" {
  name               = "default-rule-collection-group"
  firewall_policy_id = azurerm_firewall_policy.vwan.id
  priority           = 500
}

# Create Network Rule Collection
resource "azurerm_firewall_policy_rule_collection" "network_rules" {
  name                = "network-rules"
  firewall_policy_id  = azurerm_firewall_policy.vwan.id
  rule_collection_group_id = azurerm_firewall_policy_rule_collection_group.vwan.id
  priority            = 100
  rule_collection_type = "FirewallPolicyFilterRuleCollection"

  rule {
    name = "allow-https"
    protocols {
      protocol_type = "Https"
    }
    source_addresses  = ["*"]
    destination_addresses = ["*"]
    destination_ports = ["443"]
    action = "Allow"
  }

  rule {
    name = "allow-http"
    protocols {
      protocol_type = "Http"
    }
    source_addresses  = ["*"]
    destination_addresses = ["*"]
    destination_ports = ["80"]
    action = "Allow"
  }
}

# Create Application Rule Collection
resource "azurerm_firewall_policy_rule_collection" "application_rules" {
  name                = "application-rules"
  firewall_policy_id  = azurerm_firewall_policy.vwan.id
  rule_collection_group_id = azurerm_firewall_policy_rule_collection_group.vwan.id
  priority            = 200
  rule_collection_type = "FirewallPolicyFilterRuleCollection"

  rule {
    name = "allow-azure-services"
    protocols {
      port = 443
      type = "Https"
    }
    source_addresses  = ["*"]
    destination_fqdns = ["*.azure.com", "*.microsoft.com"]
    action = "Allow"
  }
}

# Use the firewall rules module to apply comprehensive rules from YAML config
module "firewall_rules" {
  source = "./modules/firewall-rules"
  
  config_file_path   = "${path.module}/firewall-config/firewall-rules.yaml"
  firewall_policy_id = azurerm_firewall_policy.vwan.id
  tags               = var.tags
} 
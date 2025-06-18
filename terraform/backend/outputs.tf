output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.terraform_state.name
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.terraform_state.name
}

output "container_name" {
  description = "The name of the storage container"
  value       = azurerm_storage_container.terraform_state.name
}

output "key_vault_name" {
  description = "The name of the key vault"
  value       = azurerm_key_vault.terraform_state.name
}

output "key_vault_key_name" {
  description = "The name of the key vault key"
  value       = azurerm_key_vault_key.terraform_state.name
} 
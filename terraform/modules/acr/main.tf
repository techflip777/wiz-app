variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

# Random string for unique ACR name
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Azure Container Registry
resource "azurerm_container_registry" "wiz_acr" {
  name                = "wizexerciseacr${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

output "acr_login_server" {
  value = azurerm_container_registry.wiz_acr.login_server
}

output "acr_admin_username" {
  value = azurerm_container_registry.wiz_acr.admin_username
}

output "acr_admin_password" {
  value     = azurerm_container_registry.wiz_acr.admin_password
  sensitive = true
} 
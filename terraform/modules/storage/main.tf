variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

# Storage Account with public access enabled
resource "azurerm_storage_account" "wiz_storage" {
  name                     = "wizex${random_string.suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = true  # Enable public network access
}

# Random string for unique storage account name
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Container with public access
resource "azurerm_storage_container" "mongodb_backups" {
  name                  = "mongodb-backups"
  storage_account_name  = azurerm_storage_account.wiz_storage.name
  container_access_type = "blob"  # Public read access for blobs
}

# Enable public access at the container level
resource "azurerm_storage_account_network_rules" "public_access" {
  storage_account_id = azurerm_storage_account.wiz_storage.id
  default_action     = "Allow"
  bypass             = ["AzureServices"]
}

output "storage_account_name" {
  value = azurerm_storage_account.wiz_storage.name
}

output "storage_account_key" {
  value     = azurerm_storage_account.wiz_storage.primary_access_key
  sensitive = true
} 
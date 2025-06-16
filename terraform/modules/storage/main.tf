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
  
  # INTENTIONAL SECURITY MISCONFIGURATIONS FOR TESTING
  public_network_access_enabled = true  # Enable public network access
  allow_nested_items_to_be_public = true  # Allow public containers
  shared_access_key_enabled = true  # Enable access keys
  
  # Disable security features for testing
  infrastructure_encryption_enabled = false
  
  blob_properties {
    # No versioning or soft delete for easier testing
    versioning_enabled = false
    delete_retention_policy {
      days = 1  # Minimal retention
    }
  }
  
  tags = {
    Environment = "SecurityTesting"
    Purpose = "VulnerableStorage"
    Risk = "HIGH"
  }
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
  container_access_type = "blob"  # Public read access for blobs - MAJOR SECURITY RISK
}

# Additional backup storage account specifically for MongoDB backups
# This account has even MORE permissive settings for testing
resource "azurerm_storage_account" "backup_storage" {
  name                     = "backups${random_string.suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # MAXIMUM SECURITY RISKS FOR TESTING
  public_network_access_enabled = true
  allow_nested_items_to_be_public = true
  shared_access_key_enabled = true
  cross_tenant_replication_enabled = true
  
  # Disable all security features
  infrastructure_encryption_enabled = false
  min_tls_version = "TLS1_0"  # Use old TLS version
  
  blob_properties {
    versioning_enabled = false
    change_feed_enabled = false
    delete_retention_policy {
      days = 1
    }
    container_delete_retention_policy {
      days = 1
    }
  }
  
  tags = {
    Environment = "SecurityTesting"
    Purpose = "PublicBackupStorage"
    Risk = "CRITICAL"
    Warning = "PubliclyAccessible"
  }
}

# Public backup container - ANYONE CAN ACCESS
resource "azurerm_storage_container" "public_backups" {
  name                  = "mongodb-backups"
  storage_account_name  = azurerm_storage_account.backup_storage.name
  container_access_type = "blob"  # Public read access - CRITICAL VULNERABILITY
}

# Enable completely open access (no restrictions)
resource "azurerm_storage_account_network_rules" "backup_public_access" {
  storage_account_id = azurerm_storage_account.backup_storage.id
  default_action     = "Allow"  # Allow all traffic
  bypass             = ["AzureServices", "Logging", "Metrics"]
}

output "storage_account_name" {
  value = azurerm_storage_account.wiz_storage.name
}

output "storage_account_key" {
  value     = azurerm_storage_account.wiz_storage.primary_access_key
  sensitive = true
}

# Backup storage outputs
output "backup_storage_account_name" {
  value = azurerm_storage_account.backup_storage.name
  description = "Name of the backup storage account (PUBLICLY ACCESSIBLE)"
}

output "backup_storage_account_key" {
  value     = azurerm_storage_account.backup_storage.primary_access_key
  sensitive = true
  description = "Primary access key for backup storage account"
}

output "backup_container_name" {
  value = azurerm_storage_container.public_backups.name
  description = "Name of the public backup container"
}

output "backup_container_url" {
  value = "https://${azurerm_storage_account.backup_storage.name}.blob.core.windows.net/${azurerm_storage_container.public_backups.name}"
  description = "Public URL of the backup container - ANYONE CAN ACCESS"
}

output "security_warning" {
  value = "WARNING: Backup storage is publicly accessible! This is intentional for security testing."
}
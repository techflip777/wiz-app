output "mongodb_vm_public_ip" {
  description = "Public IP address of the MongoDB VM"
  value       = module.mongodb.vm_public_ip
}

output "mongodb_admin_username" {
  description = "Admin username for MongoDB VM"
  value       = module.mongodb.admin_username
}

output "mongodb_admin_password" {
  description = "Admin password for MongoDB VM"
  value       = module.mongodb.admin_password
  sensitive   = true
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage.storage_account_name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "acr_login_server" {
  description = "ACR login server"
  value       = module.acr.acr_login_server
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = module.acr.acr_admin_username
}

# Backup Storage Outputs (SECURITY RISK - PUBLIC ACCESS)
output "backup_storage_account_name" {
  description = "Name of the backup storage account (PUBLICLY ACCESSIBLE)"
  value       = module.storage.backup_storage_account_name
}

output "backup_container_url" {
  description = "Public URL of the backup container - CRITICAL SECURITY RISK"
  value       = module.storage.backup_container_url
}

output "backup_security_warning" {
  description = "Security warning about public backup access"
  value       = module.storage.security_warning
}

output "mongodb_backup_info" {
  description = "Information about MongoDB backup configuration"
  value = {
    storage_account = module.storage.backup_storage_account_name
    container_name  = module.storage.backup_container_name
    public_url      = module.storage.backup_container_url
    schedule        = "Daily at 2:00 AM UTC"
    retention       = "30 days"
    security_risk   = "CRITICAL - Publicly accessible backups"
  }
}
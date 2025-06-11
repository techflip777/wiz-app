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
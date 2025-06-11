variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type = string
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "wiz_aks" {
  name                = "wiz-aks-cluster"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "wizaks"

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_D2s_v3"
    vnet_subnet_id = var.subnet_id
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    dns_service_ip     = "10.0.3.10"
    service_cidr       = "10.0.3.0/24"
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable RBAC
  role_based_access_control_enabled = true
}

# Get AKS credentials
resource "local_file" "kubeconfig" {
  content  = azurerm_kubernetes_cluster.wiz_aks.kube_config_raw
  filename = "${path.module}/kubeconfig"
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.wiz_aks.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.wiz_aks.id
} 
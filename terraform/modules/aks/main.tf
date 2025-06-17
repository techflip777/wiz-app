variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "acr_id" {
  type = string
  description = "The ID of the Azure Container Registry"
}

variable "mongodb_connection_string" {
  type        = string
  description = "MongoDB connection string"
  sensitive   = true
}

# Create a user-assigned managed identity for the AKS control plane
resource "azurerm_user_assigned_identity" "aks_control_plane" {
  name                = "aks-control-plane-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

# Create a user-assigned managed identity for the kubelet
resource "azurerm_user_assigned_identity" "aks_kubelet" {
  name                = "aks-kubelet-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

# Grant the control plane identity the Managed Identity Operator role over the kubelet identity
resource "azurerm_role_assignment" "control_plane_managed_identity_operator" {
  scope                = azurerm_user_assigned_identity.aks_kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
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
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_control_plane.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.aks_kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.aks_kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_kubelet.id
  }

  # Enable RBAC
  role_based_access_control_enabled = true

  depends_on = [
    azurerm_role_assignment.control_plane_managed_identity_operator
  ]
}

# Remove the problematic role assignment that was trying to use cluster identity
# resource "azurerm_role_assignment" "aks_identity_operator" was removed

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

output "cluster_identity_principal_id" {
  value = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

output "kubelet_identity_principal_id" {
  value = azurerm_user_assigned_identity.aks_kubelet.principal_id
}

# Configure Kubernetes provider to use the AKS cluster
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.wiz_aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.wiz_aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.wiz_aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.wiz_aks.kube_config.0.cluster_ca_certificate)
}

# Check if namespace exists and create only if it doesn't
resource "null_resource" "namespace_check" {
  provisioner "local-exec" {
    command = <<-EOF
      if ! kubectl get namespace wiz-app >/dev/null 2>&1; then
        kubectl create namespace wiz-app
      else
        echo "Namespace wiz-app already exists, skipping creation"
      fi
    EOF
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
  }
  
  depends_on = [
    azurerm_kubernetes_cluster.wiz_aks,
    local_file.kubeconfig
  ]
  
  triggers = {
    cluster_id = azurerm_kubernetes_cluster.wiz_aks.id
  }
}

# Use data source to reference the namespace (works whether created by Terraform or externally)
data "kubernetes_namespace" "wiz_app" {
  metadata {
    name = "wiz-app"
  }
  
  depends_on = [null_resource.namespace_check]
}

# Generate a random secret key for the application
resource "random_password" "app_secret_key" {
  length  = 32
  special = true
}

# Create the app-secrets secret
resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "app-secrets"
    namespace = data.kubernetes_namespace.wiz_app.metadata[0].name
  }

  data = {
    SECRET_KEY = random_password.app_secret_key.result
  }

  depends_on = [
    azurerm_kubernetes_cluster.wiz_aks,
    null_resource.namespace_check
  ]
}

# Create the mongodb-connection secret
resource "kubernetes_secret" "mongodb_connection" {
  metadata {
    name      = "mongodb-connection"
    namespace = data.kubernetes_namespace.wiz_app.metadata[0].name
  }

  data = {
    connection-string = var.mongodb_connection_string
  }

  depends_on = [
    azurerm_kubernetes_cluster.wiz_aks,
    null_resource.namespace_check
  ]
}
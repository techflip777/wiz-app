terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "wiz_exercise" {
  name     = "wiz-exercise-rg"
  location = "eastus2"
}

# Virtual Network
module "network" {
  source = "./modules/network"

  resource_group_name = azurerm_resource_group.wiz_exercise.name
  location           = azurerm_resource_group.wiz_exercise.location
}

# MongoDB VM
module "mongodb" {
  source = "./modules/mongodb"

  resource_group_name = azurerm_resource_group.wiz_exercise.name
  location           = azurerm_resource_group.wiz_exercise.location
  subnet_id          = module.network.database_subnet_id
  admin_username     = var.admin_username
  backup_storage_account_name = module.storage.backup_storage_account_name
}

# Storage Account
module "storage" {
  source = "./modules/storage"

  resource_group_name = azurerm_resource_group.wiz_exercise.name
  location           = azurerm_resource_group.wiz_exercise.location
}

# AKS Cluster
module "aks" {
  source = "./modules/aks"

  resource_group_name         = azurerm_resource_group.wiz_exercise.name
  location                   = azurerm_resource_group.wiz_exercise.location
  subnet_id                  = module.network.kubernetes_subnet_id
  acr_id                     = module.acr.acr_id
  mongodb_connection_string  = module.mongodb.connection_string
}

# Container Registry
module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.wiz_exercise.name
  location           = azurerm_resource_group.wiz_exercise.location
}

# Grant AKS cluster access to ACR (using kubelet identity for image pulls)
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = module.aks.kubelet_identity_principal_id
  role_definition_name            = "AcrPull"
  scope                           = module.acr.acr_id
  skip_service_principal_aad_check = true
} 
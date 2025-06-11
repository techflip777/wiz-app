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

  resource_group_name = azurerm_resource_group.wiz_exercise.name
  location           = azurerm_resource_group.wiz_exercise.location
  subnet_id          = module.network.kubernetes_subnet_id
}

# Container Registry
module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.wiz_exercise.name
  location           = azurerm_resource_group.wiz_exercise.location
} 
variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

resource "azurerm_virtual_network" "wiz_vnet" {
  name                = "wiz-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "database_subnet" {
  name                 = "database-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.wiz_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "kubernetes_subnet" {
  name                 = "kubernetes-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.wiz_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

output "database_subnet_id" {
  value = azurerm_subnet.database_subnet.id
}

output "kubernetes_subnet_id" {
  value = azurerm_subnet.kubernetes_subnet.id
} 
variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus2"
}

variable "admin_username" {
  description = "Username for the MongoDB VM"
  type        = string
  default     = "azureuser"
}

variable "vm_size" {
  description = "Size of the MongoDB VM"
  type        = string
  default     = "Standard_B2s"
}

variable "aks_node_count" {
  description = "Number of nodes in AKS cluster"
  type        = number
  default     = 2
}

variable "aks_node_size" {
  description = "Size of AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
} 
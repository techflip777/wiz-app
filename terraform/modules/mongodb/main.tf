variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "admin_password" {
  type    = string
  default = "Azure_123456"  # You should change this to a secure password
  sensitive = true
}

# Network Security Group with overly permissive SSH access
resource "azurerm_network_security_group" "mongodb_nsg" {
  name                = "mongodb-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-ssh-from-anywhere"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}

# Public IP for the VM
resource "azurerm_public_ip" "mongodb_pip" {
  name                = "mongodb-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                = "Standard"
}

# Network Interface
resource "azurerm_network_interface" "mongodb_nic" {
  name                = "mongodb-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mongodb_pip.id
  }
}

# Connect NSG to NIC
resource "azurerm_network_interface_security_group_association" "mongodb_nsg_association" {
  network_interface_id      = azurerm_network_interface.mongodb_nic.id
  network_security_group_id = azurerm_network_security_group.mongodb_nsg.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "mongodb_vm" {
  name                = "mongodb-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.mongodb_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  connection {
    type     = "ssh"
    user     = var.admin_username
    password = var.admin_password
    host     = azurerm_public_ip.mongodb_pip.ip_address
  }

  provisioner "remote-exec" {
    inline = [
      # Update and install MongoDB
      "sudo apt-get update -y",
      "sudo apt-get install -y gnupg curl",
      "curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor",
      "echo \"deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse\" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y mongodb-org",
      # Enable and start MongoDB
      "sudo systemctl enable mongod",
      "sudo systemctl start mongod",
      # Allow remote connections
      "sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf",
      "sudo systemctl restart mongod"
    ]
  }
}

# Assign overly permissive role to VM (Contributor)
resource "azurerm_role_assignment" "vm_contributor" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_virtual_machine.mongodb_vm.identity[0].principal_id
}

# Get current subscription
data "azurerm_client_config" "current" {}

output "vm_public_ip" {
  value = azurerm_public_ip.mongodb_pip.ip_address
}

output "admin_username" {
  value = var.admin_username
}

output "admin_password" {
  value     = var.admin_password
  sensitive = true
}

resource "azurerm_network_security_rule" "mongodb_ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  resource_group_name        = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.mongodb_nsg.name
}

resource "azurerm_network_security_rule" "mongodb_port" {
  name                        = "allow-mongodb"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "27017"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  resource_group_name        = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.mongodb_nsg.name
} 
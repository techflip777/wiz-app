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

variable "backup_storage_account_name" {
  type        = string
  description = "Name of the backup storage account"
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
      # Update and install MongoDB 4.4
      "sudo apt-get update -y",
      "sudo apt-get install -y gnupg curl",
      "curl -fsSL https://pgp.mongodb.com/server-4.4.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg --dearmor",
      "echo \"deb [ signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse\" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y mongodb-org",
      # Enable and start MongoDB
      "sudo systemctl enable mongod",
      "sudo systemctl start mongod",
      # Allow remote connections
      "sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf",
      "sudo systemctl restart mongod",
      
      # Install Azure CLI for backup uploads
      "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash",
      
      # Verify Azure CLI installation
      "az --version",
      
      # Create scripts directory
      "mkdir -p /home/azureuser/scripts",
      
      # Set environment variables
      "echo 'export AZURE_STORAGE_ACCOUNT=${var.backup_storage_account_name}' >> /home/azureuser/.bashrc",
      "echo 'export AZURE_STORAGE_ACCOUNT=${var.backup_storage_account_name}' >> /home/azureuser/.profile",
      
      # Login to Azure using managed identity
      "az login --identity",
      
      # Verify Azure login
      "az account show",
      
      # Create backup directory and set permissions
      "sudo mkdir -p /tmp/mongodb_backups",
      "sudo chown azureuser:azureuser /tmp/mongodb_backups",
      
      # Create log directory
      "sudo mkdir -p /var/log",
      "sudo touch /var/log/mongodb_backup.log",
      "sudo chown azureuser:azureuser /var/log/mongodb_backup.log"
    ]
  }
  
  # Setup MongoDB authentication and create backup scripts
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl stop mongod",
      "sudo sed -i 's/#security:/security:\\n  authorization: enabled/' /etc/mongod.conf",
      "sudo systemctl start mongod",
      "sleep 5",
      "mongo --eval \"db.getSiblingDB('admin').createUser({user: 'azureuser', pwd: 'Azure_123456', roles: [{role: 'root', db: 'admin'}]})\"",
      "mongo -u azureuser -p Azure_123456 --authenticationDatabase admin --eval \"db.getSiblingDB('todoapp').todos.insertOne({title: 'Test todo', completed: false, createdAt: new Date()})\"",
      "cat > /home/azureuser/scripts/mongodb_backup.sh << 'EOF'",
      "#!/bin/bash",
      "# MongoDB Backup Script with Azure Storage Upload",
      "# WARNING: This script uploads to a PUBLICLY ACCESSIBLE blob container",
      "# This is intentionally insecure for security testing purposes",
      "BACKUP_DIR=\"/tmp/mongodb_backups\"",
      "LOG_FILE=\"/var/log/mongodb_backup.log\"",
      "RETENTION_DAYS=30",
      "MONGODB_HOST=\"localhost\"",
      "MONGODB_PORT=\"27017\"",
      "MONGODB_DATABASE=\"todoapp\"",
      "MONGODB_USER=\"azureuser\"",
      "MONGODB_PASS=\"Azure_123456\"",
      "STORAGE_ACCOUNT_NAME=\"${var.backup_storage_account_name}\"",
      "CONTAINER_NAME=\"mongodb-backups\"",
      "mkdir -p $BACKUP_DIR",
      "log_message() {",
      "    echo \"$(date '+%Y-%m-%d %H:%M:%S') - $1\" | tee -a $LOG_FILE",
      "}",
      "TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')",
      "BACKUP_NAME=\"mongodb-backup-$TIMESTAMP\"",
      "BACKUP_PATH=\"$BACKUP_DIR/$BACKUP_NAME\"",
      "log_message \"Starting MongoDB backup process\"",
      "log_message \"Backup name: $BACKUP_NAME\"",
      "log_message \"Storage Account: $STORAGE_ACCOUNT_NAME (PUBLIC CONTAINER!)\"",
      "log_message \"Creating MongoDB dump...\"",
      "mongodump --host $MONGODB_HOST:$MONGODB_PORT --db $MONGODB_DATABASE --username $MONGODB_USER --password $MONGODB_PASS --authenticationDatabase admin --out $BACKUP_PATH",
      "if [ $? -eq 0 ]; then",
      "    log_message \"MongoDB dump completed successfully\"",
      "else",
      "    log_message \"ERROR: MongoDB dump failed\"",
      "    exit 1",
      "fi",
      "log_message \"Compressing backup...\"",
      "cd $BACKUP_DIR",
      "tar -czf \"$BACKUP_NAME.tar.gz\" \"$BACKUP_NAME\"",
      "if [ $? -eq 0 ]; then",
      "    log_message \"Backup compression completed\"",
      "    rm -rf \"$BACKUP_NAME\"",
      "else",
      "    log_message \"ERROR: Backup compression failed\"",
      "    exit 1",
      "fi",
      "log_message \"Uploading backup to Azure Storage (PUBLIC CONTAINER - SECURITY RISK!)\"",
      "# Wait for role assignments to propagate (may take a few minutes)",
      "log_message \"Waiting for Azure role assignments to propagate...\"",
      "sleep 120",
      "# Login using VM's managed identity with retry logic",
      "for i in {1..5}; do",
      "    if az login --identity --output none 2>/dev/null; then",
      "        log_message \"Successfully authenticated with managed identity\"",
      "        break",
      "    else",
      "        log_message \"Managed identity authentication attempt $i failed, waiting...\"",
      "        sleep 30",
      "    fi",
      "done",
      "# Upload to blob storage using managed identity",
      "az storage blob upload --account-name $STORAGE_ACCOUNT_NAME --container-name $CONTAINER_NAME --name \"$BACKUP_NAME.tar.gz\" --file \"$BACKUP_DIR/$BACKUP_NAME.tar.gz\" --auth-mode login --output none",
      "if [ $? -eq 0 ]; then",
      "    log_message \"Backup uploaded successfully to public blob storage\"",
      "    log_message \"WARNING: Backup is now publicly accessible at:\"",
      "    log_message \"https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/$CONTAINER_NAME/$BACKUP_NAME.tar.gz\"",
      "else",
      "    log_message \"ERROR: Failed to upload backup to Azure Storage\"",
      "    exit 1",
      "fi",
      "find $BACKUP_DIR -name \"*.tar.gz\" -mtime +$RETENTION_DAYS -delete",
      "log_message \"SECURITY WARNING: This backup is stored in a publicly accessible container!\"",
      "log_message \"Backup process completed successfully\"",
      "exit 0",
      "EOF",
      "chmod +x /home/azureuser/scripts/mongodb_backup.sh"
    ]
  }
  
  # Setup cron job for automated backups
  provisioner "remote-exec" {
    inline = [
      "cat > /home/azureuser/scripts/setup_backup_cron.sh << 'EOF'",
      "#!/bin/bash",
      "# Setup automated daily backups",
      "echo \"Setting up automated MongoDB backup cron job...\"",
      "(crontab -l 2>/dev/null; echo \"0 2 * * * /home/azureuser/scripts/mongodb_backup.sh >> /var/log/mongodb_backup_cron.log 2>&1\") | crontab -",
      "echo \"Automated backup cron job setup completed\"",
      "echo \"Backups will run daily at 2:00 AM UTC\"",
      "echo \"Listing current cron jobs:\"",
      "crontab -l",
      "EOF",
      "chmod +x /home/azureuser/scripts/setup_backup_cron.sh",
      "/home/azureuser/scripts/setup_backup_cron.sh"
    ]
  }
  
  # Test the backup script
  provisioner "remote-exec" {
    inline = [
      "echo \"VM setup completed, role assignments will be created separately...\"",
      "echo \"Backup script is ready at /home/azureuser/scripts/mongodb_backup.sh\"",
    ]
    
    # Connection details
    connection {
      type     = "ssh"
      user     = var.admin_username
      password = var.admin_password
      host     = self.public_ip_address
    }
  }
}

# Assign overly permissive role to VM (Owner - MAXIMUM security risk for testing)
resource "azurerm_role_assignment" "vm_owner" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = azurerm_linux_virtual_machine.mongodb_vm.identity[0].principal_id
}

# Additional role assignment for backup storage access
resource "azurerm_role_assignment" "vm_storage_contributor" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.mongodb_vm.identity[0].principal_id
}

# Run backup test after role assignments are created
resource "null_resource" "backup_test" {
  provisioner "remote-exec" {
    inline = [
      "echo \"Running initial backup test after role assignments...\"",
      "echo \"This may take a few minutes...\"",
      "/home/azureuser/scripts/mongodb_backup.sh"
    ]
    
    connection {
      type     = "ssh"
      user     = var.admin_username
      password = var.admin_password
      host     = azurerm_linux_virtual_machine.mongodb_vm.public_ip_address
    }
  }
  
  depends_on = [
    azurerm_role_assignment.vm_owner,
    azurerm_role_assignment.vm_storage_contributor,
    azurerm_linux_virtual_machine.mongodb_vm
  ]
}

# Get current subscription
data "azurerm_client_config" "current" {}

output "vm_public_ip" {
  value = azurerm_public_ip.mongodb_pip.ip_address
}

output "vm_private_ip" {
  value = azurerm_network_interface.mongodb_nic.private_ip_address
}

output "admin_username" {
  value = var.admin_username
}

output "admin_password" {
  value     = var.admin_password
  sensitive = true
}

output "connection_string" {
  value     = "mongodb://${var.admin_username}:${var.admin_password}@${azurerm_network_interface.mongodb_nic.private_ip_address}:27017/todoapp?authSource=admin"
  sensitive = true
  description = "MongoDB connection string for the application using private IP"
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
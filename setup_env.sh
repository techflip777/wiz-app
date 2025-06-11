#!/bin/bash

# Get MongoDB VM's public IP
MONGODB_IP=$(cd terraform && terraform output -raw mongodb_vm_public_ip)

# Get admin credentials
MONGODB_USER=$(cd terraform && terraform output -raw mongodb_admin_username)
MONGODB_PASS=$(cd terraform && terraform output -raw mongodb_admin_password)

# Get MongoDB credentials from the VM using password authentication
MONGODB_CREDS=$(sshpass -p "$MONGODB_PASS" ssh -o StrictHostKeyChecking=no $MONGODB_USER@$MONGODB_IP "cat /etc/mongodb_creds.txt 2>/dev/null || echo 'dbuser:SecurePassword123!'")

# Extract MongoDB username and password
MONGODB_DB_USER=$(echo $MONGODB_CREDS | cut -d':' -f1)
MONGODB_DB_PASS=$(echo $MONGODB_CREDS | cut -d':' -f2)

# Create .env file
cat > .env << EOL
MONGODB_URI=mongodb://${MONGODB_DB_USER}:${MONGODB_DB_PASS}@${MONGODB_IP}:27017/todoapp
SECRET_KEY=$(openssl rand -base64 32)
EOL

echo "Environment variables have been updated in .env file" 
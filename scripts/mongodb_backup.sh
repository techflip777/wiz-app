#!/bin/bash

# MongoDB Backup Script with Azure Storage Upload
# WARNING: This script uploads to a PUBLICLY ACCESSIBLE blob container
# This is intentionally insecure for security testing purposes

# Configuration
BACKUP_DIR="/tmp/mongodb_backups"
LOG_FILE="/var/log/mongodb_backup.log"
RETENTION_DAYS=30
MONGODB_HOST="localhost"
MONGODB_PORT="27017"
MONGODB_DATABASE="todoapp"
MONGODB_USER="azureuser"
MONGODB_PASS="Azure_123456"

# Azure Storage Configuration (will be set via environment variables)
STORAGE_ACCOUNT_NAME="${AZURE_STORAGE_ACCOUNT}"
CONTAINER_NAME="mongodb-backups"

# Create backup directory
mkdir -p $BACKUP_DIR

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Function to cleanup old local backups
cleanup_old_backups() {
    log_message "Cleaning up local backups older than $RETENTION_DAYS days"
    find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
}

# Generate backup filename with timestamp
TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
BACKUP_NAME="mongodb-backup-$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

log_message "Starting MongoDB backup process"
log_message "Backup name: $BACKUP_NAME"
log_message "Database: $MONGODB_DATABASE"
log_message "Host: $MONGODB_HOST:$MONGODB_PORT"

# Create MongoDB dump
log_message "Creating MongoDB dump..."
mongodump --host $MONGODB_HOST:$MONGODB_PORT \
          --db $MONGODB_DATABASE \
          --username $MONGODB_USER \
          --password $MONGODB_PASS \
          --authenticationDatabase admin \
          --out $BACKUP_PATH

if [ $? -eq 0 ]; then
    log_message "MongoDB dump completed successfully"
else
    log_message "ERROR: MongoDB dump failed"
    exit 1
fi

# Compress the backup
log_message "Compressing backup..."
cd $BACKUP_DIR
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"

if [ $? -eq 0 ]; then
    log_message "Backup compression completed"
    # Remove uncompressed backup directory
    rm -rf "$BACKUP_NAME"
else
    log_message "ERROR: Backup compression failed"
    exit 1
fi

# Upload to Azure Blob Storage (PUBLICLY ACCESSIBLE - SECURITY RISK!)
log_message "Uploading backup to Azure Storage (PUBLIC CONTAINER - SECURITY RISK!)"
log_message "Container: $CONTAINER_NAME (publicly accessible)"
log_message "Storage Account: $STORAGE_ACCOUNT_NAME"

az storage blob upload \
    --account-name $STORAGE_ACCOUNT_NAME \
    --container-name $CONTAINER_NAME \
    --name "$BACKUP_NAME.tar.gz" \
    --file "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    --auth-mode login

if [ $? -eq 0 ]; then
    log_message "Backup uploaded successfully to public blob storage"
    log_message "WARNING: Backup is now publicly accessible at:"
    log_message "https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/$CONTAINER_NAME/$BACKUP_NAME.tar.gz"
else
    log_message "ERROR: Failed to upload backup to Azure Storage"
    exit 1
fi

# Cleanup old local backups
cleanup_old_backups

# Display backup information (potentially sensitive information in logs)
log_message "Backup completed successfully"
log_message "Local backup file: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
log_message "Remote backup URL: https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/$CONTAINER_NAME/$BACKUP_NAME.tar.gz"
log_message "Database backed up: $MONGODB_DATABASE"
log_message "Records in backup: $(tar -tzf $BACKUP_DIR/$BACKUP_NAME.tar.gz | wc -l) files"

log_message "SECURITY WARNING: This backup is stored in a publicly accessible container!"
log_message "Anyone with the URL can download your database backup."

exit 0

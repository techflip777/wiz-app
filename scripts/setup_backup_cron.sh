#!/bin/bash

# Setup MongoDB Backup Cron Job
# This script sets up automated daily backups with PUBLIC storage exposure

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_message "Setting up MongoDB backup cron job..."

# Make backup script executable
chmod +x /home/azureuser/scripts/mongodb_backup.sh

# Create cron job (runs daily at 2:00 AM UTC)
CRON_JOB="0 2 * * * /home/azureuser/scripts/mongodb_backup.sh >> /var/log/mongodb_backup_cron.log 2>&1"

# Add cron job for azureuser
echo "$CRON_JOB" | crontab -

# Verify cron job was added
log_message "Cron job added successfully:"
crontab -l

# Create log directory
sudo mkdir -p /var/log
sudo touch /var/log/mongodb_backup.log
sudo touch /var/log/mongodb_backup_cron.log
sudo chown azureuser:azureuser /var/log/mongodb_backup*.log

log_message "MongoDB backup automation setup completed"
log_message "Backups will run daily at 2:00 AM UTC"
log_message "WARNING: Backups will be stored in a PUBLIC Azure container!"
log_message "Logs available at: /var/log/mongodb_backup.log"
log_message "Cron logs available at: /var/log/mongodb_backup_cron.log"

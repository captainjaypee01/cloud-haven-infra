# MySQL Database Backup Guide

This guide explains how to create, download, and manage MySQL database backups for your Cloud Haven infrastructure running on Digital Ocean.

## Overview

The backup system consists of three main scripts:
1. **backup-mysql.sh** - Creates backups on the Digital Ocean droplet
2. **download-backups.sh** - Downloads backups from droplet to local machine
3. **upload-backups-to-s3.sh** - Uploads backups to AWS S3 (optional)

## Prerequisites

- SSH access to your Digital Ocean droplet
- Docker and Docker Compose installed on the droplet
- (Optional) AWS CLI configured for cloud storage uploads

## Quick Start

### 1. Create Backups on Droplet

SSH into your Digital Ocean droplet and navigate to the infra directory:

```bash
ssh root@your-droplet-ip
cd /opt/code/cloud-haven-infra
```

Make the script executable (first time only):

```bash
chmod +x scripts/backup-mysql.sh
```

Create backups:

```bash
# Backup both production and UAT databases
./scripts/backup-mysql.sh both

# Or backup individually
./scripts/backup-mysql.sh prod
./scripts/backup-mysql.sh uat
```

Backups will be saved to: `/opt/code/cloud-haven-infra/backups/`

### 2. Download Backups to Local Machine

From your local machine, navigate to the infra directory:

```bash
cd cloud-haven-infra
chmod +x scripts/download-backups.sh
```

Download backups:

```bash
# Download both environments
./scripts/download-backups.sh both

# Or download individually
./scripts/download-backups.sh prod
./scripts/download-backups.sh uat
```

The script will prompt for:
- Droplet IP or hostname
- SSH user (default: root)

Backups will be downloaded to: `cloud-haven-infra/backups/downloaded/`

### 3. Upload to Cloud Storage (Optional)

#### AWS S3

```bash
# Set AWS credentials (if not already configured)
aws configure

# Upload backups
AWS_BUCKET=your-backup-bucket ./scripts/upload-backups-to-s3.sh both backups/mysql/
```

#### Manual Cloud Storage Upload

You can also manually upload the backup files from `backups/downloaded/` to:
- Google Drive
- Dropbox
- OneDrive
- Any other cloud storage service

## Automated Backups

### Using Cron (Recommended)

Set up automated daily backups on your droplet:

```bash
# Edit crontab
crontab -e

# Add this line for daily backups at 2 AM
0 2 * * * cd /opt/code/cloud-haven-infra && ./scripts/backup-mysql.sh both >> /var/log/mysql-backup.log 2>&1
```

### Backup Retention

The backup script automatically deletes backups older than 7 days. To change this, edit `backup-mysql.sh` and modify:

```bash
find "$BACKUP_DIR" -name "${env}_${DB_NAME}_*.sql.gz" -mtime +7 -delete
```

Change `+7` to your desired retention period (e.g., `+30` for 30 days).

## Backup File Naming

Backups are named with the following format:
```
{environment}_{database_name}_{timestamp}.sql.gz

Examples:
- prod_cloudhaven_prod_20240115_020000.sql.gz
- uat_cloudhaven_uat_20240115_020000.sql.gz
```

## Restoring Backups

### On Droplet

```bash
# Uncompress the backup
gunzip backup_file.sql.gz

# Restore to production
docker exec -i mysql-prod mysql -ucloudhaven_prod -p cloudhaven_prod < backup_file.sql

# Restore to UAT
docker exec -i mysql-uat mysql -ucloudhaven_uat -p cloudhaven_uat < backup_file.sql
```

### From Local Machine

```bash
# Copy backup to droplet
scp backup_file.sql.gz root@your-droplet-ip:/tmp/

# SSH into droplet
ssh root@your-droplet-ip

# Uncompress and restore
gunzip /tmp/backup_file.sql.gz
docker exec -i mysql-prod mysql -ucloudhaven_prod -p cloudhaven_prod < /tmp/backup_file.sql
```

## Troubleshooting

### Container Not Found

If you see "Container not found" error:
- Check container name: `docker ps -a`
- Ensure you're in the correct directory
- Verify docker-compose.yml is configured correctly

### Permission Denied

```bash
# Make scripts executable
chmod +x scripts/*.sh
```

### Backup File Too Large

If backups are very large, consider:
- Excluding certain tables
- Using compression (already enabled with `.gz`)
- Increasing disk space on droplet

### SSH Connection Issues

- Verify SSH key is added to droplet
- Check firewall settings
- Ensure SSH service is running

## Best Practices

1. **Regular Backups**: Set up automated daily backups
2. **Test Restores**: Periodically test restoring backups to ensure they work
3. **Off-Site Storage**: Always keep backups in cloud storage, not just on the droplet
4. **Monitor Disk Space**: Ensure droplet has enough space for backups
5. **Encryption**: Consider encrypting backups before uploading to cloud storage
6. **Documentation**: Keep track of backup schedules and locations

## Backup Locations Summary

| Location | Path | Purpose |
|----------|------|---------|
| Droplet | `/opt/code/cloud-haven-infra/backups/` | Primary backup storage |
| Local | `cloud-haven-infra/backups/downloaded/` | Local copies |
| S3 | `s3://your-bucket/backups/mysql/` | Cloud archive (optional) |

## Security Notes

- Backup files contain sensitive database data
- Store backups securely
- Use strong passwords for database access
- Consider encrypting backups before cloud upload
- Limit access to backup files (chmod 600)




# MySQL Database Backup Guide

This guide explains how to create, download, and manage MySQL database backups for your Cloud Haven infrastructure running on Digital Ocean.

## Overview

Main scripts:
1. **backup-mysql.sh** - Creates compressed MySQL dumps on the droplet
2. **backup-config.sh** - Archives application/infra config (`prod/`, `uat/`, `proxy/`, `scripts/`, optional `dev/`) into `config_cloudhaven_*.tar.gz` (excludes `backups/` and `.git/`)
3. **backup-and-upload-gdrive.sh** - Runs MySQL + config backups, then uploads new files to Google Drive via **rclone**
4. **upload-backups-to-gdrive.sh** - Upload only (if you already ran the backup scripts)
5. **download-backups.sh** - Downloads backups from droplet to your PC
6. **upload-backups-to-s3.sh** - Uploads MySQL dumps to AWS S3 (optional)

## Prerequisites

- SSH access to your Digital Ocean droplet
- Docker and Docker Compose installed on the droplet
- (Optional) AWS CLI configured for cloud storage uploads
- (Optional) [rclone](https://rclone.org/) for Google Drive uploads from the droplet

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

#### Google Drive (from the droplet, automated)

Google does not ship a Linux “Drive sync” CLI like the desktop app. The usual approach is **[rclone](https://rclone.org/)** with a Drive remote you configure once.

1. **Install rclone** on the droplet (see [rclone install](https://rclone.org/install/)).
2. **Configure a remote** (interactive, one time):
   ```bash
   rclone config
   ```
   Create a remote (e.g. name `gdrive`), choose Google Drive, and complete the browser OAuth step.
3. **Pick where files should go** on Drive:
   - **By path** (folder under “My Drive”): use `REMOTE:path`, e.g. `gdrive:CloudHaven/backups`.
   - **By folder link** (URL like `https://drive.google.com/drive/folders/FOLDER_ID`): the long id after `/folders/` is the **folder ID**. Point rclone at it in either way:
     - In `rclone config`, edit the remote → **advanced** → set **`root_folder_id`** to that id, then use `RCLONE_DEST=gdrive:` (same remote name you chose); or
     - Leave the remote default and set **`RCLONE_FLAGS=--drive-root-folder-id FOLDER_ID`** with **`RCLONE_DEST=gdrive:`**. If you already use `RCLONE_FLAGS` (e.g. `--bwlimit`), put several flags in one quoted value, e.g. `RCLONE_FLAGS="--drive-root-folder-id FOLDER_ID --bwlimit 8M"`.
4. **Store settings for cron** (do not commit secrets; copy from the example file):
   ```bash
   cp scripts/backup-cron.env.example /root/.config/cloud-haven-backup.env
   # Edit: set RCLONE_DEST=gdrive:YourFolder/backups
   ```
5. **Dry run backups without upload**:
   ```bash
   cd /opt/code/cloud-haven-infra
   chmod +x scripts/*.sh
   SKIP_GDRIVE_UPLOAD=1 ./scripts/backup-and-upload-gdrive.sh both
   ```
6. **Test upload** (uploads files in `backups/` modified in the last 30 hours by default):
   ```bash
   export RCLONE_DEST=gdrive:CloudHaven/backups
   ./scripts/upload-backups-to-gdrive.sh
   ```

`upload-backups-to-gdrive.sh` uploads:

- `prod_*.sql.gz`, `uat_*.sql.gz`
- `config_cloudhaven_*.tar.gz` (from `backup-config.sh`)

To upload **everything** matching those patterns (e.g. first migration), run once with `GDRIVE_UPLOAD_ALL=1`. To change the “recent files” window, set `GDRIVE_UPLOAD_MAX_AGE_MINUTES` (default `1800` = 30 hours so daily cron still picks yesterday if the job is delayed).

#### Manual Cloud Storage Upload

You can also manually upload files from `backups/` or `backups/downloaded/` to Dropbox, OneDrive, etc.

## Automated Backups

### MySQL only (cron)

```bash
crontab -e
# Daily at 2 AM
0 2 * * * cd /opt/code/cloud-haven-infra && ./scripts/backup-mysql.sh both >> /var/log/mysql-backup.log 2>&1
```

### MySQL + config archive + Google Drive (cron)

This runs database dumps, a **config tarball** (Compose files, `env/*.env`, proxy, scripts), then **rclone** upload of files touched in the last ~30 hours (so old dumps on disk are not re-uploaded every night).

```bash
crontab -e
# Daily at 3 AM — load env then run orchestrator
0 3 * * * set -a; . /root/.config/cloud-haven-backup.env; set +a; cd /opt/code/cloud-haven-infra && ./scripts/backup-and-upload-gdrive.sh both >> /var/log/cloud-haven-backup.log 2>&1
```

### What is *not* in `backup-config.sh`

The config archive is everything under **this repo on the server** (`prod/`, `uat/`, `proxy/`, `scripts/`, etc.). It does **not** automatically include unrelated host paths (for example system-wide nginx under `/etc/nginx` if you installed nginx outside Docker). If you rely on host-level config, document it and either add it to your own tar step or move that config into the repo/proxy layout you deploy.

### Backup Retention

MySQL dumps and `config_cloudhaven_*.tar.gz` archives older than **7 days** are removed on the droplet by `backup-mysql.sh` and `backup-config.sh` (config retention uses `BACKUP_CONFIG_RETENTION_DAYS`, default 7). To change MySQL retention, edit `backup-mysql.sh` and modify:

```bash
find "$BACKUP_DIR" -name "${env}_${DB_NAME}_*.sql.gz" -mtime +7 -delete
```

Change `+7` to your desired retention period (e.g., `+30` for 30 days).

## Backup File Naming

MySQL dumps:

```
{environment}_{database_name}_{timestamp}.sql.gz

Examples:
- prod_cloudhaven_prod_20240115_020000.sql.gz
- uat_cloudhaven_uat_20240115_020000.sql.gz
```

Config / application archive:

```
config_cloudhaven_{timestamp}.tar.gz
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
| Droplet | `/opt/code/cloud-haven-infra/backups/` | SQL dumps + `config_cloudhaven_*.tar.gz` |
| Local | `cloud-haven-infra/backups/downloaded/` | Local copies (download script) |
| Google Drive | Folder you set in `RCLONE_DEST` | Off-site copy (rclone) |
| S3 | `s3://your-bucket/backups/mysql/` | Cloud archive (optional) |

## Security Notes

- Backup files contain sensitive database data
- Store backups securely
- Use strong passwords for database access
- Consider encrypting backups before cloud upload
- Limit access to backup files (chmod 600)




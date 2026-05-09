#!/bin/bash

# Droplet: MySQL dump + infra/config archive, then upload to Google Drive (rclone).
#
# Usage:
#   ./scripts/backup-and-upload-gdrive.sh [prod|uat|both]
#
# Environment:
#   RCLONE_DEST          Required for upload. Example: gdrive_cloudhaven:Portfolio/Freelance Projects/Cloud Haven/BACKUP
#   SKIP_GDRIVE_UPLOAD   If set to 1, only run local backups (no rclone).
#   RCLONE_FLAGS         Optional extra rclone flags (see upload-backups-to-gdrive.sh)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_ARG="${1:-both}"

"$SCRIPT_DIR/backup-mysql.sh" "$ENV_ARG"
"$SCRIPT_DIR/backup-config.sh"

if [ "${SKIP_GDRIVE_UPLOAD:-0}" = "1" ]; then
    echo "SKIP_GDRIVE_UPLOAD=1 — skipping Google Drive upload."
    exit 0
fi

if [ -z "${RCLONE_DEST:-}" ]; then
    echo "Error: set RCLONE_DEST for Google Drive upload (e.g. export RCLONE_DEST='gdrive_cloudhaven:Portfolio/Freelance Projects/Cloud Haven/BACKUP')" >&2
    echo "Or set SKIP_GDRIVE_UPLOAD=1 to only create local backups." >&2
    exit 1
fi

"$SCRIPT_DIR/upload-backups-to-gdrive.sh"

#!/bin/bash

# Upload MySQL dumps and config archives to Google Drive using rclone.
#
# One-time on the droplet: install rclone, then `rclone config` and create a remote
# (name it e.g. "gdrive"). Authorize browser OAuth when prompted.
#
# Usage:
#   export RCLONE_DEST=gdrive:CloudHaven/backups
#   ./scripts/upload-backups-to-gdrive.sh
#
# Environment:
#   RCLONE_DEST                    Required. rclone remote + path, e.g. gdrive:folder/subfolder
#   RCLONE_FLAGS                   Optional. Extra rclone flags (space-separated), e.g. --bwlimit 5M
#   GDRIVE_UPLOAD_MAX_AGE_MINUTES  Only upload files modified within this window (default: 1800 = 30h)
#   GDRIVE_UPLOAD_ALL              Set to 1 to upload every matching file (first run / migration)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$(cd "$SCRIPT_DIR/../backups" && pwd)"

if ! command -v rclone >/dev/null 2>&1; then
    echo -e "${RED}Error: rclone is not installed.${NC}" >&2
    echo "See https://rclone.org/install/" >&2
    exit 1
fi

if [ -z "${RCLONE_DEST:-}" ]; then
    echo -e "${RED}Error: set RCLONE_DEST, e.g. export RCLONE_DEST=gdrive:CloudHaven/backups${NC}" >&2
    exit 1
fi

echo -e "${GREEN}=== Uploading backups to Google Drive ===${NC}"
echo -e "${YELLOW}Destination: ${RCLONE_DEST}${NC}"
echo -e "${YELLOW}Source: ${BACKUP_DIR}${NC}"

FIND_ARGS=(
    "$BACKUP_DIR" -maxdepth 1 -type f '('
    -name 'prod_*.sql.gz' -o
    -name 'uat_*.sql.gz' -o
    -name 'config_cloudhaven_*.tar.gz'
    ')'
)
if [ "${GDRIVE_UPLOAD_ALL:-0}" != "1" ]; then
    _age="${GDRIVE_UPLOAD_MAX_AGE_MINUTES:-1800}"
    FIND_ARGS+=( -mmin "-${_age}" )
    echo -e "${YELLOW}Only files modified in the last ${_age} minutes (set GDRIVE_UPLOAD_ALL=1 to upload all matches)${NC}"
fi

uploaded=0
while IFS= read -r file; do
    [ -z "$file" ] && continue
    base=$(basename "$file")
    echo -e "${YELLOW}  → ${base}${NC}"
    # shellcheck disable=SC2086
    if [ -n "${RCLONE_FLAGS:-}" ]; then
        rclone copyto "$file" "${RCLONE_DEST}/${base}" ${RCLONE_FLAGS}
    else
        rclone copyto "$file" "${RCLONE_DEST}/${base}"
    fi
    uploaded=$((uploaded + 1))
done < <(find "${FIND_ARGS[@]}" | sort)

if [ "$uploaded" -eq 0 ]; then
    echo -e "${YELLOW}No matching backup files in ${BACKUP_DIR}${NC}"
else
    echo -e "${GREEN}✓ Uploaded ${uploaded} file(s)${NC}"
fi

echo -e "${GREEN}=== Done ===${NC}"

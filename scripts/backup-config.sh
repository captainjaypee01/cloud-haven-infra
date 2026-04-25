#!/bin/bash

# Archive application and infra configuration (Docker Compose, env files, proxy, scripts).
# Run on the droplet after deploy; complements backup-mysql.sh (database dumps).
#
# Creates: backups/config_cloudhaven_<timestamp>.tar.gz
# Excludes: backups/ (avoids nesting SQL dumps), .git/
#
# Usage:
#   ./scripts/backup-config.sh
#
# Optional: set BACKUP_CONFIG_RETENTION_DAYS (default 7) to tune old archive cleanup.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="${INFRA_DIR}/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE="${BACKUP_DIR}/config_cloudhaven_${TIMESTAMP}.tar.gz"
RETENTION_DAYS="${BACKUP_CONFIG_RETENTION_DAYS:-7}"

mkdir -p "$BACKUP_DIR"

TAR_PARTS=(prod uat proxy scripts)
if [ -d "${INFRA_DIR}/dev" ]; then
    TAR_PARTS+=(dev)
fi
if [ -f "${INFRA_DIR}/README.md" ]; then
    TAR_PARTS+=(README.md)
fi

echo -e "${GREEN}=== Config / application backup ===${NC}"
echo -e "${YELLOW}Source: ${INFRA_DIR}${NC}"
echo -e "${YELLOW}Archive: ${ARCHIVE}${NC}"

cd "$INFRA_DIR"

if ! tar -czf "$ARCHIVE" \
    --exclude='backups' \
    --exclude='.git' \
    --exclude='*.sql.gz' \
    --exclude='*.sql' \
    "${TAR_PARTS[@]}"; then
    echo -e "${RED}✗ tar failed${NC}"
    exit 1
fi

SIZE=$(du -h "$ARCHIVE" | cut -f1)
echo -e "${GREEN}✓ Created ${ARCHIVE} (${SIZE})${NC}"

find "$BACKUP_DIR" -maxdepth 1 -name 'config_cloudhaven_*.tar.gz' -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true
echo -e "${GREEN}=== Config backup done (retention: ${RETENTION_DAYS} days) ===${NC}"

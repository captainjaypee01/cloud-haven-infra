#!/bin/bash

# MySQL Restore Script for Docker Compose
# Restores a backup file to Production or UAT MySQL database
#
# Usage:
#   ./scripts/restore-mysql.sh [prod|uat] <backup_file.sql.gz>
#
# Example:
#   ./scripts/restore-mysql.sh prod backups/prod_cloudhaven_prod_20240115_020000.sql.gz

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo -e "${YELLOW}Usage: $0 [prod|uat] <backup_file.sql.gz>${NC}"
    exit 1
fi

ENV=$1
BACKUP_FILE=$2

# Validate environment
if [ "$ENV" != "prod" ] && [ "$ENV" != "uat" ]; then
    echo -e "${RED}Error: Invalid environment. Use 'prod' or 'uat'${NC}"
    exit 1
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file not found: ${BACKUP_FILE}${NC}"
    exit 1
fi

# Set container and environment file
CONTAINER_NAME="mysql-${ENV}"
ENV_FILE="${INFRA_DIR}/${ENV}/env/${ENV}.mysql.env"

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Container ${CONTAINER_NAME} not found${NC}"
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Container ${CONTAINER_NAME} is not running${NC}"
    exit 1
fi

# Load environment variables
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: Environment file not found: ${ENV_FILE}${NC}"
    exit 1
fi

source "$ENV_FILE"

# Set database name
if [ "$ENV" = "prod" ]; then
    DB_NAME="${MYSQL_DATABASE:-cloudhaven_prod}"
else
    DB_NAME="${MYSQL_DATABASE:-cloudhaven_uat}"
fi

# Warning prompt
echo -e "${RED}⚠️  WARNING: This will overwrite the ${ENV} database!${NC}"
echo -e "${YELLOW}Database: ${DB_NAME}${NC}"
echo -e "${YELLOW}Backup file: ${BACKUP_FILE}${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    exit 0
fi

# Check if backup is compressed
TEMP_FILE=""
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo -e "${YELLOW}Decompressing backup file...${NC}"
    TEMP_FILE=$(mktemp)
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
    RESTORE_FILE="$TEMP_FILE"
else
    RESTORE_FILE="$BACKUP_FILE"
fi

# Restore database
echo -e "${YELLOW}Restoring database: ${DB_NAME}${NC}"
echo -e "${YELLOW}This may take a few minutes...${NC}"

if docker exec -i "${CONTAINER_NAME}" mysql \
    -u"${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    "${DB_NAME}" < "$RESTORE_FILE"; then
    
    echo -e "${GREEN}✓ Database restored successfully${NC}"
    
    # Cleanup temp file if created
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
        rm "$TEMP_FILE"
    fi
else
    echo -e "${RED}✗ Database restore failed${NC}"
    
    # Cleanup temp file if created
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
        rm "$TEMP_FILE"
    fi
    
    exit 1
fi




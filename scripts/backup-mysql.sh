#!/bin/bash

# MySQL Backup Script for Docker Compose
# Creates backups for both Production and UAT MySQL databases
#
# Usage:
#   ./scripts/backup-mysql.sh [prod|uat|both]
#   Default: both

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="${INFRA_DIR}/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to backup a database
backup_database() {
    local env=$1
    local container_name="mysql-${env}"
    local env_file="${INFRA_DIR}/${env}/env/${env}.mysql.env"
    
    echo -e "${YELLOW}Creating backup for ${env} database...${NC}"
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${RED}Error: Container ${container_name} not found${NC}"
        return 1
    fi
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${RED}Error: Container ${container_name} is not running${NC}"
        return 1
    fi
    
    # Load environment variables
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}Error: Environment file not found: ${env_file}${NC}"
        return 1
    fi
    
    source "$env_file"
    
    # Set database name based on environment
    if [ "$env" = "prod" ]; then
        DB_NAME="${MYSQL_DATABASE:-cloudhaven_prod}"
    else
        DB_NAME="${MYSQL_DATABASE:-cloudhaven_uat}"
    fi
    
    # Backup filename
    BACKUP_FILE="${BACKUP_DIR}/${env}_${DB_NAME}_${TIMESTAMP}.sql.gz"
    
    echo -e "${YELLOW}Backing up database: ${DB_NAME}${NC}"
    echo -e "${YELLOW}Container: ${container_name}${NC}"
    
    # Create backup using mysqldump inside the container
    if docker exec "${container_name}" mysqldump \
        -u"${MYSQL_USER}" \
        -p"${MYSQL_PASSWORD}" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        "${DB_NAME}" | gzip > "$BACKUP_FILE"; then
        
        # Get file size
        FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        
        echo -e "${GREEN}✓ Backup created successfully: ${BACKUP_FILE}${NC}"
        echo -e "${GREEN}  Size: ${FILE_SIZE}${NC}"
        
        # Keep only last 7 days of backups (optional cleanup)
        find "$BACKUP_DIR" -name "${env}_${DB_NAME}_*.sql.gz" -mtime +7 -delete
        
        return 0
    else
        echo -e "${RED}✗ Backup failed for ${env} database${NC}"
        return 1
    fi
}

# Main execution
ENV_ARG="${1:-both}"

case "$ENV_ARG" in
    prod)
        backup_database "prod"
        ;;
    uat)
        backup_database "uat"
        ;;
    both)
        echo -e "${GREEN}=== Starting MySQL Backup Process ===${NC}"
        echo -e "${GREEN}Timestamp: ${TIMESTAMP}${NC}\n"
        
        backup_database "prod"
        echo ""
        backup_database "uat"
        
        echo -e "\n${GREEN}=== Backup Process Completed ===${NC}"
        echo -e "${GREEN}Backup location: ${BACKUP_DIR}${NC}"
        ;;
    *)
        echo -e "${RED}Error: Invalid argument. Use 'prod', 'uat', or 'both'${NC}"
        exit 1
        ;;
esac




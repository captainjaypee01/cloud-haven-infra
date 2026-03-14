#!/bin/bash

# Download MySQL Backups from Digital Ocean Droplet to Local Machine
#
# Usage:
#   ./scripts/download-backups.sh [prod|uat|both] [remote_path]
#
# Prerequisites:
#   - SSH access to your Digital Ocean droplet
#   - Backups directory exists on the droplet
#
# Example:
#   ./scripts/download-backups.sh both /opt/code/cloud-haven-infra/backups

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BACKUP_DIR="${SCRIPT_DIR}/../backups/downloaded"
ENV_ARG="${1:-both}"
REMOTE_BACKUP_DIR="${2:-/opt/code/cloud-haven-infra/backups}"

# Prompt for SSH connection details if not set
if [ -z "$DROPLET_IP" ] && [ -z "$DROPLET_USER" ]; then
    echo -e "${YELLOW}Enter your Digital Ocean droplet details:${NC}"
    read -p "Droplet IP or hostname: " DROPLET_IP
    read -p "SSH user (default: root): " DROPLET_USER
    DROPLET_USER="${DROPLET_USER:-root}"
fi

DROPLET_USER="${DROPLET_USER:-root}"

# Ensure local backup directory exists
mkdir -p "$LOCAL_BACKUP_DIR"

# Function to download backups
download_backups() {
    local env=$1
    local pattern="${env}_*.sql.gz"
    
    echo -e "${YELLOW}Downloading ${env} backups...${NC}"
    
    # Create remote directory if it doesn't exist
    ssh "${DROPLET_USER}@${DROPLET_IP}" "mkdir -p ${REMOTE_BACKUP_DIR}"
    
    # Download files matching the pattern
    if scp "${DROPLET_USER}@${DROPLET_IP}:${REMOTE_BACKUP_DIR}/${pattern}" "$LOCAL_BACKUP_DIR/" 2>/dev/null; then
        echo -e "${GREEN}✓ ${env} backups downloaded successfully${NC}"
        
        # List downloaded files
        echo -e "${YELLOW}Downloaded files:${NC}"
        ls -lh "$LOCAL_BACKUP_DIR" | grep "${env}_" || echo "  (no files found)"
    else
        echo -e "${RED}✗ Failed to download ${env} backups${NC}"
        echo -e "${YELLOW}Note: Make sure backups exist on the remote server${NC}"
    fi
}

# Main execution
case "$ENV_ARG" in
    prod)
        download_backups "prod"
        ;;
    uat)
        download_backups "uat"
        ;;
    both)
        echo -e "${GREEN}=== Downloading MySQL Backups ===${NC}"
        echo -e "${GREEN}From: ${DROPLET_USER}@${DROPLET_IP}:${REMOTE_BACKUP_DIR}${NC}"
        echo -e "${GREEN}To: ${LOCAL_BACKUP_DIR}${NC}\n"
        
        download_backups "prod"
        echo ""
        download_backups "uat"
        
        echo -e "\n${GREEN}=== Download Completed ===${NC}"
        echo -e "${GREEN}Local backup location: ${LOCAL_BACKUP_DIR}${NC}"
        ;;
    *)
        echo -e "${RED}Error: Invalid argument. Use 'prod', 'uat', or 'both'${NC}"
        exit 1
        ;;
esac




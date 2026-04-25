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
#
# Non-interactive: set DROPLET_IP, DROPLET_USER, DROPLET_PORT, and optionally DROPLET_SSH_KEY.

set -e

# Normalize a user-entered or env-provided path for ssh -i (Git Bash / MSYS friendly).
# Echoes resolved path or empty. Exits 1 on .ppk (PuTTY-only; OpenSSH cannot use it).
resolve_ssh_key_path() {
    local p="$1"
    # trim whitespace
    p="${p#"${p%%[![:space:]]*}"}"
    p="${p%"${p##*[![:space:]]}"}"
    # strip surrounding quotes from pasted "C:\..."
    p="${p#\"}"
    p="${p%\"}"
    p="${p#\'}"
    p="${p%\'}"
    [ -z "$p" ] && return 0
    # OpenSSH / Git Bash cannot load PuTTY .ppk; user needs Export OpenSSH key from PuTTYgen
    case "$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')" in
        *.ppk)
            echo -e "${RED}Error: PuTTY .ppk files are not supported by ssh/scp (OpenSSH).${NC}" >&2
            echo "Export an OpenSSH private key from PuTTYgen: Conversions → Export OpenSSH key," >&2
            echo "or run: puttygen your-key.ppk -O private-openssh -o your-key.pem" >&2
            echo "Then use the .pem (or extensionless) file path here." >&2
            exit 1
            ;;
    esac
    # tilde
    if [[ "$p" == ~* ]]; then
        p="${p/#\~/$HOME}"
    fi
    # Windows C:\... → /c/... for MSYS/Git Bash
    if command -v cygpath >/dev/null 2>&1 && [[ "$p" =~ ^[a-zA-Z]:[\\/] ]]; then
        p=$(cygpath -u -- "$p")
    elif [[ "$p" =~ ^[a-zA-Z]:[\\/] ]]; then
        local dl rest
        dl="${p:0:1}"
        dl=$(printf '%s' "$dl" | tr '[:upper:]' '[:lower:]')
        rest="${p:2}"
        rest="${rest//\\//}"
        rest="${rest#/}"
        p="/${dl}/${rest}"
    fi
    printf '%s' "$p"
    return 0
}

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
    read -r -p "Droplet IP or hostname: " DROPLET_IP
    read -r -p "SSH user (default: root): " DROPLET_USER
    DROPLET_USER="${DROPLET_USER:-root}"
    read -r -p "SSH port (default: 22): " DROPLET_PORT
    DROPLET_PORT="${DROPLET_PORT:-22}"
    # Optional: OpenSSH private key path (not PuTTY .ppk). Use forward slashes or a normal Windows path.
    if [ -z "${DROPLET_SSH_KEY:-}" ]; then
        read -r -p "SSH private key path (optional, Enter for default keys; use .pem/OpenSSH, not .ppk): " DROPLET_SSH_KEY
    fi
fi

DROPLET_USER="${DROPLET_USER:-root}"
DROPLET_PORT="${DROPLET_PORT:-22}"

# Optional: path to private key (fixes "Permission denied (publickey)" when the default key is wrong)
SSH_IDENTITY_ARGS=()
if [ -n "${DROPLET_SSH_KEY:-}" ]; then
    KEY_PATH="$(resolve_ssh_key_path "$DROPLET_SSH_KEY")"
    if [ -n "$KEY_PATH" ]; then
        if [ ! -f "$KEY_PATH" ]; then
            echo -e "${RED}Error: SSH private key file not found:${NC} ${KEY_PATH}"
            exit 1
        fi
        SSH_IDENTITY_ARGS=(-i "$KEY_PATH" -o IdentitiesOnly=yes)
    fi
fi

# Ensure local backup directory exists
mkdir -p "$LOCAL_BACKUP_DIR"

# Function to download backups
download_backups() {
    local env=$1
    local pattern="${env}_*.sql.gz"
    
    echo -e "${YELLOW}Downloading ${env} backups...${NC}"
    # Create remote directory if it doesn't exist
    ssh "${SSH_IDENTITY_ARGS[@]}" -p "${DROPLET_PORT}" "${DROPLET_USER}@${DROPLET_IP}" "mkdir -p ${REMOTE_BACKUP_DIR}"
    
    # Download files matching the pattern
    if scp "${SSH_IDENTITY_ARGS[@]}" -P "${DROPLET_PORT}" "${DROPLET_USER}@${DROPLET_IP}:${REMOTE_BACKUP_DIR}/${pattern}" "$LOCAL_BACKUP_DIR/"; then
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




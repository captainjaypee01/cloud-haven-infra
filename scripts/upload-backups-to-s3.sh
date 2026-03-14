#!/bin/bash

# Upload MySQL Backups to AWS S3
#
# Usage:
#   ./scripts/upload-backups-to-s3.sh [prod|uat|both] [s3_bucket_path]
#
# Prerequisites:
#   - AWS CLI installed and configured
#   - AWS credentials with S3 write permissions
#   - Backups directory exists locally
#
# Environment Variables:
#   AWS_BUCKET - S3 bucket name (or pass as second argument)
#   AWS_REGION - AWS region (default: us-east-1)
#
# Example:
#   AWS_BUCKET=my-backups-bucket ./scripts/upload-backups-to-s3.sh both backups/mysql/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BACKUP_DIR="${SCRIPT_DIR}/../backups"
ENV_ARG="${1:-both}"
S3_PATH="${2:-backups/mysql/}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo -e "${YELLOW}Install it with: pip install awscli${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo -e "${YELLOW}Run: aws configure${NC}"
    exit 1
fi

# Get bucket name
if [ -z "$AWS_BUCKET" ]; then
    read -p "Enter S3 bucket name: " AWS_BUCKET
fi

AWS_REGION="${AWS_REGION:-us-east-1}"

# Function to upload backups
upload_backups() {
    local env=$1
    local pattern="${env}_*.sql.gz"
    
    echo -e "${YELLOW}Uploading ${env} backups to S3...${NC}"
    
    # Find and upload matching files
    local uploaded=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local s3_key="${S3_PATH}${filename}"
            
            echo -e "${YELLOW}  Uploading: ${filename}${NC}"
            
            if aws s3 cp "$file" "s3://${AWS_BUCKET}/${s3_key}" --region "$AWS_REGION"; then
                echo -e "${GREEN}  ✓ Uploaded: ${filename}${NC}"
                uploaded=$((uploaded + 1))
            else
                echo -e "${RED}  ✗ Failed to upload: ${filename}${NC}"
            fi
        fi
    done < <(find "$LOCAL_BACKUP_DIR" -name "$pattern" -type f)
    
    if [ $uploaded -eq 0 ]; then
        echo -e "${YELLOW}  No ${env} backup files found to upload${NC}"
    else
        echo -e "${GREEN}✓ Uploaded ${uploaded} ${env} backup file(s)${NC}"
    fi
}

# Main execution
case "$ENV_ARG" in
    prod)
        upload_backups "prod"
        ;;
    uat)
        upload_backups "uat"
        ;;
    both)
        echo -e "${GREEN}=== Uploading MySQL Backups to S3 ===${NC}"
        echo -e "${GREEN}Bucket: s3://${AWS_BUCKET}/${S3_PATH}${NC}"
        echo -e "${GREEN}Region: ${AWS_REGION}${NC}\n"
        
        upload_backups "prod"
        echo ""
        upload_backups "uat"
        
        echo -e "\n${GREEN}=== Upload Completed ===${NC}"
        ;;
    *)
        echo -e "${RED}Error: Invalid argument. Use 'prod', 'uat', or 'both'${NC}"
        exit 1
        ;;
esac




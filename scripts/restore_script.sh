#!/bin/bash

# Vaultwarden Backup Restoration Script
# This script restores Vaultwarden data from S3 backups

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
BACKUP_DIR="${PROJECT_ROOT}/restore_temp"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    exit 1
fi

# Required variables check
required_vars=("S3_BUCKET_NAME" "S3_ACCESS_KEY" "S3_SECRET_KEY" "BACKUP_ENCRYPTION_KEY" "S3_PATH")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: Required variable $var is not set in .env${NC}"
        exit 1
    fi
done

# Functions
print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

list_backups() {
    print_step "Listing available backups from S3..."
    
    docker run --rm \
        -e AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
        -e AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
        -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}" \
        amazon/aws-cli s3 ls "s3://${S3_BUCKET_NAME}/${S3_PATH}/" \
        ${S3_ENDPOINT:+--endpoint-url=${S3_ENDPOINT_PROTO:-https}://${S3_ENDPOINT}} \
        | grep -E "\.tar\.gz(\.gpg)?$" \
        | sort -r
}

download_backup() {
    local backup_file="$1"
    
    print_step "Downloading backup: $backup_file"
    
    mkdir -p "$BACKUP_DIR"
    
    docker run --rm \
        -v "$BACKUP_DIR:/backup" \
        -e AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
        -e AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
        -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}" \
        amazon/aws-cli s3 cp \
        "s3://${S3_BUCKET_NAME}/${S3_PATH}/${backup_file}" \
        "/backup/${backup_file}" \
        ${S3_ENDPOINT:+--endpoint-url=${S3_ENDPOINT_PROTO:-https}://${S3_ENDPOINT}}
    
    echo -e "${GREEN}Download complete${NC}"
}

decrypt_backup() {
    local encrypted_file="$1"
    local decrypted_file="${encrypted_file%.gpg}"
    
    print_step "Decrypting backup..."
    
    docker run --rm \
        -v "$BACKUP_DIR:/backup" \
        -w /backup \
        vladgh/gpg \
        gpg --batch --yes --passphrase "$BACKUP_ENCRYPTION_KEY" \
        --decrypt -o "$decrypted_file" "$encrypted_file"
    
    echo -e "${GREEN}Decryption complete${NC}"
    echo "$decrypted_file"
}

stop_vaultwarden() {
    print_step "Stopping Vaultwarden container..."
    cd "$PROJECT_ROOT"
    docker compose stop vaultwarden
    echo -e "${GREEN}Vaultwarden stopped${NC}"
}

extract_backup() {
    local backup_file="$1"
    
    print_step "Extracting backup..."
    
    # Get the volume path
    local volume_path=$(docker volume inspect vaultwarden-backup-stack_vaultwarden-data -f '{{ .Mountpoint }}')
    
    if [ -z "$volume_path" ]; then
        print_error "Could not find vaultwarden-data volume"
        exit 1
    fi
    
    print_warning "This will overwrite existing data in the volume!"
    read -p "Continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Restore cancelled"
        exit 0
    fi
    
    # Extract backup to volume
    docker run --rm \
        -v "$BACKUP_DIR:/backup" \
        -v vaultwarden-backup-stack_vaultwarden-data:/restore \
        ubuntu:latest \
        bash -c "rm -rf /restore/* && tar -xzf /backup/$backup_file -C /restore --strip-components=3"
    
    echo -e "${GREEN}Extraction complete${NC}"
}

start_vaultwarden() {
    print_step "Starting Vaultwarden container..."
    cd "$PROJECT_ROOT"
    docker compose up -d vaultwarden
    
    # Wait for health check
    print_step "Waiting for Vaultwarden to become healthy..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker compose ps vaultwarden | grep -q "healthy"; then
            echo -e "${GREEN}Vaultwarden is healthy!${NC}"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    print_error "Vaultwarden did not become healthy within expected time"
    print_warning "Check logs with: docker compose logs vaultwarden"
    return 1
}

cleanup() {
    print_step "Cleaning up temporary files..."
    rm -rf "$BACKUP_DIR"
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Main script
main() {
    echo "=========================================="
    echo "  Vaultwarden Backup Restoration Script  "
    echo "=========================================="
    echo ""
    
    # List available backups
    echo "Available backups:"
    list_backups
    echo ""
    
    # Prompt for backup selection
    read -p "Enter the backup filename to restore (or 'latest' for most recent): " backup_selection
    
    if [ "$backup_selection" == "latest" ]; then
        backup_file=$(list_backups | head -1 | awk '{print $NF}')
        echo "Selected latest backup: $backup_file"
    else
        backup_file="$backup_selection"
    fi
    
    if [ -z "$backup_file" ]; then
        print_error "No backup file specified"
        exit 1
    fi
    
    # Download backup
    download_backup "$backup_file"
    
    # Decrypt if encrypted
    local_backup_file="$BACKUP_DIR/$backup_file"
    if [[ "$backup_file" == *.gpg ]]; then
        local_backup_file=$(decrypt_backup "$local_backup_file")
    fi
    
    # Extract filename only
    local_backup_file=$(basename "$local_backup_file")
    
    # Stop Vaultwarden
    stop_vaultwarden
    
    # Extract backup
    extract_backup "$local_backup_file"
    
    # Start Vaultwarden
    start_vaultwarden
    
    # Cleanup
    cleanup
    
    echo ""
    echo -e "${GREEN}=========================================="
    echo "  Restoration Complete!"
    echo "==========================================${NC}"
    echo ""
    echo "Your Vaultwarden instance has been restored from backup."
    echo "Please verify that everything is working correctly."
    echo ""
    echo "Useful commands:"
    echo "  - View logs: docker compose logs -f vaultwarden"
    echo "  - Check status: docker compose ps"
    echo "  - Access admin panel: ${SERVICE_URL_VAULTWARDEN}/admin"
}

# Trap errors
trap 'print_error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"
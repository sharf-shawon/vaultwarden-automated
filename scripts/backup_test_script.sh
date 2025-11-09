#!/bin/bash

# Vaultwarden Backup Test Script
# This script triggers a manual backup for testing purposes

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if backup container is running
print_step "Checking backup container status..."
if ! docker compose -f "$PROJECT_ROOT/docker-compose.yml" ps backup | grep -q "Up"; then
    print_error "Backup container is not running"
    echo "Start it with: docker compose up -d backup"
    exit 1
fi

echo -e "${GREEN}Backup container is running${NC}"
echo ""

# Trigger manual backup
print_step "Triggering manual backup..."
echo "This will create a backup immediately and upload it to S3."
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Backup cancelled"
    exit 0
fi

# Execute backup
print_step "Running backup..."
docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec backup backup

echo ""
print_step "Backup process initiated!"
echo ""
echo "Monitor the backup progress with:"
echo "  docker compose logs -f backup"
echo ""
echo "To verify the backup was uploaded to S3, check your S3 bucket:"
echo "  Bucket: \$S3_BUCKET_NAME"
echo "  Path: \$S3_PATH"
echo ""
echo -e "${YELLOW}Note:${NC} The backup may take a few moments to complete and upload."
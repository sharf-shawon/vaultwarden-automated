# =============================================================================
# VAULTWARDEN CONFIGURATION
# =============================================================================

# Service URL - Full URL where Vaultwarden will be accessible
# Example: https://vault.example.com
SERVICE_URL_VAULTWARDEN=https://vault.example.com

# Admin Token - Secure token for accessing admin panel (/admin)
# Generate with: openssl rand -base64 48
SERVICE_PASSWORD_64_ADMIN=

# Database URL - Leave default for SQLite, or use PostgreSQL connection string
# SQLite (default): /data/db.sqlite3
# PostgreSQL: postgresql://user:password@host:5432/vaultwarden
VAULTWARDEN_DB_URL=/data/db.sqlite3

# Allow new user signups (true/false)
SIGNUP_ALLOWED=false

# Allow existing users to invite new users (true/false)
INVITATIONS_ALLOWED=true

# Enable emergency access feature (true/false)
EMERGENCY_ACCESS_ALLOWED=true

# Show password hints (not recommended for security)
SHOW_PASSWORD_HINT=false

# Vaultwarden port (only used if not behind reverse proxy)
VAULTWARDEN_PORT=8080

# Logging level (trace, debug, info, warn, error, off)
LOG_LEVEL=info

# Extended logging for troubleshooting
EXTENDED_LOGGING=true

# =============================================================================
# PUSH NOTIFICATIONS (Optional - requires Bitwarden Push Relay)
# =============================================================================

# Enable push notifications
PUSH_ENABLED=false

# Push service installation ID (from https://bitwarden.com/host)
PUSH_SERVICE_ID=

# Push service installation key
PUSH_SERVICE_KEY=

# =============================================================================
# S3 BACKUP CONFIGURATION
# =============================================================================

# S3 Bucket name where backups will be stored
S3_BUCKET_NAME=

# S3 Access Key ID
S3_ACCESS_KEY=

# S3 Secret Access Key
S3_SECRET_KEY=

# S3 Endpoint (leave empty for AWS, or specify for S3-compatible services)
# Examples: 
#   - DigitalOcean Spaces: nyc3.digitaloceanspaces.com
#   - Backblaze B2: s3.us-west-002.backblazeb2.com
#   - Wasabi: s3.wasabisys.com
#   - MinIO: minio.example.com
S3_ENDPOINT=

# S3 Endpoint Protocol (https or http)
S3_ENDPOINT_PROTO=https

# S3 Path prefix within bucket (optional)
S3_PATH=vaultwarden-backups

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================

# Backup schedule in cron format (default: daily at 2 AM)
# Examples:
#   - Every 6 hours: 0 */6 * * *
#   - Daily at 2 AM: 0 2 * * *
#   - Weekly on Sunday at 3 AM: 0 3 * * 0
BACKUP_CRON=0 2 * * *

# Backup filename pattern (supports date formatting)
BACKUP_FILENAME=vaultwarden-backup-%Y-%m-%dT%H-%M-%S.tar.gz

# Symlink to latest backup
BACKUP_LATEST_SYMLINK=vaultwarden-backup-latest.tar.gz

# Number of days to retain backups (older backups are deleted)
BACKUP_RETENTION_DAYS=15

# Backup pruning leeway (time buffer for deletion)
BACKUP_PRUNING_LEEWAY=1m

# Backup compression (gz, bz2, xz, zst)
BACKUP_COMPRESSION=gz

# Encryption passphrase for backup files (AES-256 via GPG)
# Generate with: openssl rand -base64 32
BACKUP_ENCRYPTION_KEY=

# Stop containers during backup for consistency (backup.stop=true label required)
# Leave empty to keep containers running during backup
BACKUP_STOP_DURING_BACKUP=

# Forward backup command output to logs
BACKUP_EXEC_FORWARD_OUTPUT=true

# =============================================================================
# BACKUP NOTIFICATIONS (Optional)
# =============================================================================

# Notification URLs for backup status (supports multiple services)
# Examples:
#   - Email: smtp://username:password@smtp.example.com:587/?from=backup@example.com&to=admin@example.com
#   - Slack: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
#   - Discord: https://discord.com/api/webhooks/YOUR/WEBHOOK
#   - Generic webhook: https://your-webhook-endpoint.com
# Multiple URLs separated by commas
BACKUP_NOTIFICATION_URLS=

# Notification level (error, info)
BACKUP_NOTIFICATION_LEVEL=error

# =============================================================================
# WATCHTOWER CONFIGURATION
# =============================================================================

# Update check interval in seconds (default: 86400 = 24 hours)
WATCHTOWER_POLL_INTERVAL=86400

# Notification URL for update events (optional)
WATCHTOWER_NOTIFICATION_URL=

# Notification level for Watchtower (panic, fatal, error, warn, info, debug, trace)
WATCHTOWER_NOTIFICATION_LEVEL=info

# =============================================================================
# SYSTEM CONFIGURATION
# =============================================================================

# Timezone for containers (affects backup scheduling and logs)
TZ=UTC

# =============================================================================
# OPTIONAL: POSTGRESQL CONFIGURATION (if using external database)
# =============================================================================

# PostgreSQL user
POSTGRES_USER=vaultwarden

# PostgreSQL password
POSTGRES_PASSWORD=

# PostgreSQL database name
POSTGRES_DB=vaultwarden
# Vaultwarden Production Deployment Stack

A comprehensive, production-ready Vaultwarden deployment with automated S3 backups, automatic updates, and Coolify compatibility.

## 🚀 Features

- **Automated Encrypted S3 Backups**
  - Daily backups to S3-compatible storage
  - AES-256 encryption via GPG
  - 15-day retention with automatic cleanup
  - Backup integrity verification
  - Easy restore functionality

- **Automatic Updates**
  - Zero-downtime rolling updates via Watchtower
  - Scoped updates for trusted containers
  - Automatic cleanup of old images

- **Coolify Compatible**
  - Environment variable prompts during deployment
  - Pre-configured deployment profiles
  - User-friendly setup experience

- **Production Ready**
  - Health checks for all services
  - Comprehensive logging
  - Optional external database support
  - Reverse proxy configuration examples
  - Security best practices

## 📋 Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- S3-compatible storage (AWS S3, DigitalOcean Spaces, Backblaze B2, Wasabi, MinIO, etc.)
- (Optional) Coolify for simplified deployment
- Minimum 1GB RAM, 2GB recommended
- 10GB+ storage for data and backups

## 🏗️ Repository Structure

```
vaultwarden-backup-stack/
├── docker-compose.yml              # Main compose configuration
├── docker-compose.override.yml     # Optional overrides for development
├── coolify.env                     # Environment variables template
├── README.md                       # This file
├── scripts/
│   ├── restore.sh                  # Backup restoration script
│   └── backup-test.sh              # Manual backup testing
└── docs/
    ├── recovery-guide.md           # Detailed recovery instructions
    ├── backup-architecture.md      # Backup system architecture
    └── coolify-deploy.md           # Coolify deployment guide
```

## 🚀 Quick Start

### Option 1: Deploy with Coolify (Recommended)

1. **Import the repository** into Coolify
2. **Configure environment variables** through the Coolify UI
3. **Deploy** and let Coolify handle the rest

See [Coolify Deployment Guide](docs/coolify-deploy.md) for detailed instructions.

### Option 2: Manual Deployment

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd vaultwarden-backup-stack
   ```

2. **Configure environment variables:**
   ```bash
   cp coolify.env .env
   nano .env
   ```

3. **Generate required secrets:**
   ```bash
   # Admin token
   openssl rand -base64 48
   
   # Backup encryption key
   openssl rand -base64 32
   ```

4. **Start the stack:**
   ```bash
   docker compose up -d
   ```

5. **Verify deployment:**
   ```bash
   docker compose ps
   docker compose logs -f
   ```

## ⚙️ Configuration

### Essential Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SERVICE_URL_VAULTWARDEN` | Full URL where Vaultwarden is accessible | Yes |
| `SERVICE_PASSWORD_64_ADMIN` | Admin panel access token | Yes |
| `S3_BUCKET_NAME` | S3 bucket for backups | Yes |
| `S3_ACCESS_KEY` | S3 access key ID | Yes |
| `S3_SECRET_KEY` | S3 secret access key | Yes |
| `BACKUP_ENCRYPTION_KEY` | Backup encryption passphrase | Yes |

See `coolify.env` for all available configuration options.

### S3-Compatible Storage Providers

#### AWS S3
```bash
S3_ENDPOINT=
S3_ENDPOINT_PROTO=https
```

#### DigitalOcean Spaces
```bash
S3_ENDPOINT=nyc3.digitaloceanspaces.com
S3_ENDPOINT_PROTO=https
```

#### Backblaze B2
```bash
S3_ENDPOINT=s3.us-west-002.backblazeb2.com
S3_ENDPOINT_PROTO=https
```

#### Wasabi
```bash
S3_ENDPOINT=s3.wasabisys.com
S3_ENDPOINT_PROTO=https
```

#### MinIO (Self-hosted)
```bash
S3_ENDPOINT=minio.example.com
S3_ENDPOINT_PROTO=https
```

## 🔄 Backup System

### How Backups Work

1. **Scheduled Execution**: Backup runs daily at 2 AM (configurable)
2. **Data Collection**: Creates compressed archive of `/data` volume
3. **Encryption**: Encrypts archive with GPG using AES-256
4. **Upload**: Uploads to S3 with timestamp
5. **Retention**: Automatically deletes backups older than 15 days
6. **Notification**: (Optional) Sends status to webhook/email

### Manual Backup

Trigger a backup immediately:

```bash
./scripts/backup-test.sh
```

Or directly:

```bash
docker compose exec backup backup
```

### Backup Schedule

Default: Daily at 2 AM UTC

Customize with cron expression in `.env`:

```bash
# Every 6 hours
BACKUP_CRON=0 */6 * * *

# Daily at 3 AM
BACKUP_CRON=0 3 * * *

# Weekly on Sunday at midnight
BACKUP_CRON=0 0 * * 0
```

## 🔧 Recovery & Restoration

### Quick Recovery

Run the automated restore script:

```bash
./scripts/restore.sh
```

The script will:
1. List available backups from S3
2. Download selected backup
3. Decrypt the backup
4. Stop Vaultwarden
5. Restore data
6. Start Vaultwarden
7. Verify health

### Manual Recovery

See [Recovery Guide](docs/recovery-guide.md) for detailed manual recovery instructions.

## 🔄 Updates

Watchtower automatically checks for and applies updates every 24 hours.

### Manual Update

Force an immediate update:

```bash
docker compose exec watchtower /watchtower --run-once
```

### Update Notifications

Configure notifications in `.env`:

```bash
WATCHTOWER_NOTIFICATION_URL=slack://token@channel
```

## 🔒 Security

### Best Practices Implemented

- ✅ Encrypted backups with AES-256
- ✅ Read-only access to data for backup container
- ✅ Health checks for service availability
- ✅ No hardcoded secrets
- ✅ Least privilege container permissions
- ✅ Secrets management support (Docker secrets/Coolify)
- ✅ Regular automatic updates

### Securing Your Deployment

1. **Use strong passwords:**
   ```bash
   # Generate secure admin token
   openssl rand -base64 48
   ```

2. **Disable signups** after creating accounts:
   ```bash
   SIGNUP_ALLOWED=false
   ```

3. **Enable HTTPS** (use reverse proxy with SSL)

4. **Regular backups verification:**
   ```bash
   ./scripts/backup-test.sh
   ```

5. **Monitor logs:**
   ```bash
   docker compose logs -f
   ```

## 🔍 Monitoring & Troubleshooting

### Check Service Status

```bash
docker compose ps
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f vaultwarden
docker compose logs -f backup
docker compose logs -f watchtower
```

### Verify Backup

```bash
# Trigger test backup
./scripts/backup-test.sh

# Check S3 for uploaded backup
# Use your S3 provider's console or CLI
```

### Common Issues

#### Backup Container Fails to Start

**Symptom**: Backup container exits immediately

**Solution**: Check environment variables:
```bash
docker compose logs backup
# Ensure S3_BUCKET_NAME, S3_ACCESS_KEY, S3_SECRET_KEY are set
```

#### Vaultwarden Not Accessible

**Symptom**: Cannot access Vaultwarden web interface

**Solution**: Check health status and logs:
```bash
docker compose ps vaultwarden
docker compose logs vaultwarden
# Verify SERVICE_URL_VAULTWARDEN is correct
```

#### S3 Upload Fails

**Symptom**: Backups not appearing in S3 bucket

**Solution**: Verify S3 credentials and endpoint:
```bash
# Test S3 access
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
  -e AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
  amazon/aws-cli s3 ls "s3://$S3_BUCKET_NAME" \
  --endpoint-url="$S3_ENDPOINT_PROTO://$S3_ENDPOINT"
```

#### Restore Fails

**Symptom**: Restore script encounters errors

**Solution**: Verify backup file integrity:
```bash
# Check backup file exists in S3
# Verify BACKUP_ENCRYPTION_KEY matches the one used for backup
```

## 📊 Performance Optimization

### For Small Deployments (<100 users)

Default SQLite configuration is sufficient.

### For Medium/Large Deployments (>100 users)

Consider using PostgreSQL:

1. Uncomment PostgreSQL service in `docker-compose.override.yml`
2. Update `VAULTWARDEN_DB_URL`:
   ```bash
   VAULTWARDEN_DB_URL=postgresql://vaultwarden:password@postgres:5432/vaultwarden
   ```
3. Restart stack:
   ```bash
   docker compose down
   docker compose up -d
   ```

## 🔗 Additional Resources

- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Docker Volume Backup Documentation](https://github.com/offen/docker-volume-backup)
- [Watchtower Documentation](https://containrrr.dev/watchtower/)
- [Coolify Documentation](https://coolify.io/docs)

## 📝 License

This deployment configuration is provided as-is for use with Vaultwarden.

## 🤝 Contributing

Contributions welcome! Please submit issues and pull requests.

## ⚠️ Disclaimer

This is a deployment configuration. Always test in a non-production environment first and maintain your own backup verification procedures.

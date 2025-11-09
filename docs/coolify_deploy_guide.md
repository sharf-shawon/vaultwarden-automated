# Coolify Deployment Guide

This guide walks you through deploying the Vaultwarden stack using Coolify.

## Prerequisites

- Coolify instance running and accessible
- S3-compatible storage credentials
- Domain name configured (for HTTPS access)
- Basic understanding of environment variables

## Deployment Steps

### Step 1: Add Resource in Coolify

1. **Log into Coolify dashboard**

2. **Navigate to your project**

3. **Click "New Resource"**

4. **Select "Docker Compose"**

### Step 2: Configure Repository

1. **Repository URL**: Enter your Git repository URL
   ```
   https://github.com/yourusername/vaultwarden-backup-stack
   ```

2. **Branch**: `main` (or your preferred branch)

3. **Docker Compose Location**: `/docker-compose.yml`

4. **Click "Continue"**

### Step 3: Configure Environment Variables

Coolify will automatically detect the required environment variables. Configure each one:

#### Vaultwarden Settings

**SERVICE_URL_VAULTWARDEN**
- Description: Full URL where Vaultwarden will be accessible
- Example: `https://vault.yourdomain.com`
- Required: ✅

**SERVICE_PASSWORD_64_ADMIN**
- Description: Admin panel access token
- Generate: `openssl rand -base64 48`
- Required: ✅
- ⚠️ Store securely!

**SIGNUP_ALLOWED**
- Description: Allow new user registrations
- Options: `true` or `false`
- Recommended: `false` (enable only when needed)
- Default: `false`

**VAULTWARDEN_DB_URL**
- Description: Database connection string
- Default: `/data/db.sqlite3` (SQLite)
- For PostgreSQL: `postgresql://user:pass@host:5432/db`
- Leave default unless using external database

#### S3 Backup Configuration

**S3_BUCKET_NAME**
- Description: S3 bucket name for backups
- Example: `my-vaultwarden-backups`
- Required: ✅

**S3_ACCESS_KEY**
- Description: S3 access key ID
- Required: ✅
- ⚠️ Store securely!

**S3_SECRET_KEY**
- Description: S3 secret access key
- Required: ✅
- ⚠️ Store securely!

**S3_ENDPOINT**
- Description: S3 endpoint URL (leave empty for AWS)
- Examples:
  - AWS S3: (leave empty)
  - DigitalOcean: `nyc3.digitaloceanspaces.com`
  - Backblaze B2: `s3.us-west-002.backblazeb2.com`
  - Wasabi: `s3.wasabisys.com`
  - MinIO: `minio.yourdomain.com`

**S3_PATH**
- Description: Path prefix within bucket for backups
- Example: `vaultwarden-backups`
- Required: ✅

#### Backup Settings

**BACKUP_ENCRYPTION_KEY**
- Description: Encryption passphrase for backups
- Generate: `openssl rand -base64 32`
- Required: ✅
- ⚠️ CRITICAL: Store securely! Cannot recover backups without this!

**BACKUP_CRON**
- Description: Backup schedule (cron format)
- Default: `0 2 * * *` (daily at 2 AM)
- Examples:
  - Every 6 hours: `0 */6 * * *`
  - Every 12 hours: `0 */12 * * *`
  - Weekly: `0 2 * * 0`

**BACKUP_RETENTION_DAYS**
- Description: Days to keep backups
- Default: `15`
- Recommended: 15-30 days

#### Optional Settings

**INVITATIONS_ALLOWED**
- Description: Allow users to invite others
- Default: `true`

**PUSH_ENABLED**
- Description: Enable push notifications
- Default: `false`
- Requires: Push relay credentials from Bitwarden

**LOG_LEVEL**
- Description: Logging verbosity
- Options: `trace`, `debug`, `info`, `warn`, `error`
- Default: `info`

**WATCHTOWER_POLL_INTERVAL**
- Description: Update check interval (seconds)
- Default: `86400` (24 hours)

**TZ**
- Description: Timezone for logs and scheduling
- Example: `America/New_York`, `Europe/London`, `Asia/Tokyo`
- Default: `UTC`

### Step 4: Configure Domain and Networking

1. **Domain Settings**
   - Add your domain: `vault.yourdomain.com`
   - Enable "Generate SSL Certificate"
   - Let Coolify handle HTTPS automatically

2. **Port Configuration**
   - Coolify will handle port mapping automatically
   - Default internal port: 8080

3. **Network Settings**
   - Use default bridge network
   - No additional configuration needed

### Step 5: Deploy

1. **Review Configuration**
   - Double-check all environment variables
   - Ensure S3 credentials are correct
   - Verify domain configuration

2. **Click "Deploy"**

3. **Monitor Deployment**
   - Watch deployment logs in Coolify
   - Verify all containers start successfully
   - Check for any error messages

### Step 6: Verify Deployment

1. **Check Service Status**
   - In Coolify dashboard, verify all services are running:
     - ✅ vaultwarden
     - ✅ backup
     - ✅ watchtower

2. **Access Vaultwarden**
   - Navigate to your domain: `https://vault.yourdomain.com`
   - Should see Vaultwarden login page

3. **Test Admin Panel**
   - Go to: `https://vault.yourdomain.com/admin`
   - Enter admin token
   - Verify access

4. **Verify Backup**
   - Wait for first scheduled backup (or trigger manually)
   - Check S3 bucket for backup files
   - Verify backup is encrypted (`.gpg` extension)

## Deployment Profiles

### Minimal Profile (Personal Use)

Ideal for: 1-5 users, personal password manager

**Configuration:**
```bash
SIGNUP_ALLOWED=false
INVITATIONS_ALLOWED=true
BACKUP_CRON=0 2 * * *          # Daily
BACKUP_RETENTION_DAYS=15
WATCHTOWER_POLL_INTERVAL=86400  # Daily
LOG_LEVEL=info
```

### Production Profile (Small Team)

Ideal for: 5-50 users, team password manager

**Configuration:**
```bash
SIGNUP_ALLOWED=false
INVITATIONS_ALLOWED=true
BACKUP_CRON=0 */12 * * *        # Every 12 hours
BACKUP_RETENTION_DAYS=30
WATCHTOWER_POLL_INTERVAL=86400  # Daily
LOG_LEVEL=info
PUSH_ENABLED=true               # If configured
```

**Additional Requirements:**
- Consider using PostgreSQL (uncomment in docker-compose.override.yml)
- Monitor backups regularly
- Test recovery procedures

### High-Security Profile (Enterprise)

Ideal for: 50+ users, critical infrastructure

**Configuration:**
```bash
SIGNUP_ALLOWED=false
INVITATIONS_ALLOWED=false       # Admin-only user creation
BACKUP_CRON=0 */6 * * *         # Every 6 hours
BACKUP_RETENTION_DAYS=90
WATCHTOWER_POLL_INTERVAL=86400
LOG_LEVEL=warn
EXTENDED_LOGGING=true
PUSH_ENABLED=true
```

**Additional Requirements:**
- Use external PostgreSQL database
- Enable backup notifications
- Multiple backup destinations
- Regular security audits
- Access logging and monitoring

## Post-Deployment Configuration

### Create First User

1. **Temporarily enable signups:**
   ```bash
   # In Coolify, update environment variable:
   SIGNUP_ALLOWED=true
   # Redeploy
   ```

2. **Register account** at your domain

3. **Disable signups:**
   ```bash
   SIGNUP_ALLOWED=false
   # Redeploy
   ```

### Configure Push Notifications (Optional)

1. **Get credentials** from [Bitwarden Push Relay](https://bitwarden.com/host)

2. **Update environment variables:**
   ```bash
   PUSH_ENABLED=true
   PUSH_SERVICE_ID=your_installation_id
   PUSH_SERVICE_KEY=your_installation_key
   ```

3. **Redeploy**

### Test Backup and Restore

1. **Trigger manual backup:**
   - SSH into server
   - Run: `docker compose exec backup backup`

2. **Verify backup in S3:**
   - Check your S3 bucket
   - Confirm encrypted backup exists

3. **Test restore** (in staging if possible):
   ```bash
   ./scripts/restore.sh
   ```

## Monitoring in Coolify

### View Logs

1. **Navigate to deployment** in Coolify
2. **Click "Logs"**
3. **Select service:**
   - vaultwarden: Application logs
   - backup: Backup operation logs
   - watchtower: Update logs

### Health Checks

Coolify monitors container health automatically:
- Green: Healthy
- Yellow: Starting
- Red: Unhealthy

### Resource Usage

Monitor in Coolify dashboard:
- CPU usage
- Memory usage
- Network traffic
- Disk usage

## Updating Configuration

### Modify Environment Variables

1. **Go to deployment settings** in Coolify
2. **Click "Environment Variables"**
3. **Update values**
4. **Click "Redeploy"**

⚠️ **Note**: Changing certain variables requires restart:
- Database URL
- S3 credentials
- Backup encryption key (⚠️ will affect existing backups!)

### Update Docker Compose

1. **Push changes** to Git repository
2. **In Coolify**, click "Redeploy"
3. **Coolify pulls latest** configuration automatically

## Troubleshooting

### Deployment Fails

**Check logs in Coolify:**
1. View deployment logs
2. Look for error messages
3. Verify environment variables

**Common issues:**
- Missing required environment variables
- Invalid S3 credentials
- Domain not resolving
- Port conflicts

### Backup Not Working

**Verify configuration:**
```bash
# Check backup container logs in Coolify
# Look for S3 connection errors
```

**Test S3 connectivity:**
1. SSH into server
2. Run:
   ```bash
   docker compose exec backup sh -c "env | grep S3"
   ```

### Cannot Access Vaultwarden

**Check:**
1. Domain DNS is correctly configured
2. SSL certificate generated successfully
3. Vaultwarden container is healthy
4. No firewall blocking ports 80/443

### Admin Panel Not Accessible

**Verify:**
1. Admin token is correctly set
2. No whitespace in token
3. Token was properly generated (base64)

## Security Best Practices

### Secrets Management

1. **Use Coolify's secret storage:**
   - Store sensitive values as secrets
   - Reference in environment variables
   - Never commit secrets to Git

2. **Rotate credentials regularly:**
   - Admin token: Every 90 days
   - Backup encryption key: Document before rotating!
   - S3 credentials: Follow your S3 provider's recommendations

### Access Control

1. **Limit admin access:**
   - Only trusted personnel should have admin token
   - Use invitation system for user management

2. **Monitor access:**
   - Review Coolify access logs
   - Check Vaultwarden admin panel regularly

### Backup Security

1. **Test restores regularly:**
   - Monthly: Quick restore test
   - Quarterly: Full disaster recovery drill

2. **Multiple backup locations:**
   - Consider backing up to multiple S3 providers
   - Keep offline backup of critical data

3. **Encryption key backup:**
   - Store in password manager
   - Keep offline copy in secure location
   - Document key rotation procedures

## Advanced Configuration

### Custom Backup Schedule

Multiple daily backups:
```bash
BACKUP_CRON=0 */6 * * *  # Every 6 hours
```

### Email Notifications

Configure backup notifications:
```bash
BACKUP_NOTIFICATION_URLS=smtp://user:pass@smtp.gmail.com:587/?from=backup@domain.com&to=admin@domain.com
BACKUP_NOTIFICATION_LEVEL=info
```

### External Database

1. **Add PostgreSQL** to docker-compose.yml
2. **Update connection string:**
   ```bash
   VAULTWARDEN_DB_URL=postgresql://vaultwarden:password@postgres:5432/vaultwarden
   ```
3. **Redeploy**

### Custom Domain with Subdirectory

If running under subdirectory:
```bash
SERVICE_URL_VAULTWARDEN=https://yourdomain.com/vault
```

⚠️ Requires reverse proxy configuration

## Support and Resources

- **Coolify Documentation**: https://coolify.io/docs
- **Vaultwarden Wiki**: https://github.com/dani-garcia/vaultwarden/wiki
- **Repository Issues**: For deployment-specific questions
- **Community Support**: Coolify Discord, Vaultwarden discussions

## Checklist

Before going live:

- [ ] All environment variables configured
- [ ] Domain DNS pointing to server
- [ ] SSL certificate generated
- [ ] Admin token set and secured
- [ ] S3 credentials tested
- [ ] Backup encryption key generated and stored
- [ ] First backup completed successfully
- [ ] Restore procedure tested
- [ ] Admin panel accessible
- [ ] First user account created
- [ ] Signups disabled
- [ ] Documentation reviewed
- [ ] Monitoring configured
- [ ] Backup retention verified

---

**Congratulations!** Your Vaultwarden instance is now deployed on Coolify with automated backups and updates.
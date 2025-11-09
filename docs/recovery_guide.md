# Vaultwarden Recovery Guide

This guide provides comprehensive instructions for recovering your Vaultwarden instance from backups in various scenarios.

## Table of Contents

- [Quick Recovery (Automated)](#quick-recovery-automated)
- [Manual Recovery (Step-by-Step)](#manual-recovery-step-by-step)
- [Partial Recovery](#partial-recovery)
- [Emergency Recovery Scenarios](#emergency-recovery-scenarios)
- [Verification Procedures](#verification-procedures)
- [Troubleshooting](#troubleshooting)

## Quick Recovery (Automated)

The automated restore script handles the entire recovery process.

### Prerequisites

- Access to the server where Vaultwarden is deployed
- S3 credentials configured in `.env`
- Backup encryption key (same as used for backups)

### Steps

1. **Navigate to project directory:**
   ```bash
   cd vaultwarden-backup-stack
   ```

2. **Run restore script:**
   ```bash
   ./scripts/restore.sh
   ```

3. **Follow prompts:**
   - View list of available backups
   - Select backup to restore (or choose 'latest')
   - Confirm restoration

4. **Wait for completion:**
   - Script will download, decrypt, and restore automatically
   - Vaultwarden will be restarted
   - Health check will verify successful restoration

### What the Script Does

1. Lists available backups from S3
2. Downloads selected backup
3. Decrypts backup using encryption key
4. Stops Vaultwarden container
5. Extracts backup to volume
6. Starts Vaultwarden container
7. Verifies health
8. Cleans up temporary files

## Manual Recovery (Step-by-Step)

For cases where the automated script cannot be used or for learning purposes.

### Step 1: Identify Backup

**List available backups:**

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID="your_access_key" \
  -e AWS_SECRET_ACCESS_KEY="your_secret_key" \
  amazon/aws-cli s3 ls \
  "s3://your-bucket/vaultwarden-backups/" \
  --endpoint-url="https://your-endpoint" | \
  grep -E "\.tar\.gz(\.gpg)?$" | \
  sort -r
```

**Choose backup:**
- Most recent: First in list
- Specific date: Find by timestamp in filename
- Example: `vaultwarden-backup-2024-11-09T02-00-00.tar.gz.gpg`

### Step 2: Download Backup

**Create temporary directory:**
```bash
mkdir -p ./restore_temp
cd restore_temp
```

**Download from S3:**
```bash
docker run --rm \
  -v $(pwd):/backup \
  -e AWS_ACCESS_KEY_ID="your_access_key" \
  -e AWS_SECRET_ACCESS_KEY="your_secret_key" \
  amazon/aws-cli s3 cp \
  "s3://your-bucket/vaultwarden-backups/vaultwarden-backup-2024-11-09T02-00-00.tar.gz.gpg" \
  /backup/ \
  --endpoint-url="https://your-endpoint"
```

### Step 3: Decrypt Backup

**If backup is encrypted (`.gpg` extension):**

```bash
docker run --rm \
  -v $(pwd):/backup \
  -w /backup \
  vladgh/gpg \
  gpg --batch --yes \
  --passphrase "your_encryption_key" \
  --decrypt -o vaultwarden-backup-2024-11-09T02-00-00.tar.gz \
  vaultwarden-backup-2024-11-09T02-00-00.tar.gz.gpg
```

**Verify decryption:**
```bash
ls -lh *.tar.gz
# Should show unencrypted tar.gz file
```

### Step 4: Stop Vaultwarden

**Stop container:**
```bash
cd ../
docker compose stop vaultwarden
```

**Verify stopped:**
```bash
docker compose ps vaultwarden
# Status should show "Exited"
```

### Step 5: Backup Current Data (Optional but Recommended)

**Create safety backup:**
```bash
docker run --rm \
  -v vaultwarden-backup-stack_vaultwarden-data:/data:ro \
  -v $(pwd):/backup \
  ubuntu:latest \
  tar czf /backup/pre-restore-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .
```

This allows rollback if restoration fails.

### Step 6: Clear Existing Data

**Remove current data:**
```bash
docker run --rm \
  -v vaultwarden-backup-stack_vaultwarden-data:/data \
  ubuntu:latest \
  rm -rf /data/*
```

**⚠️ Warning**: This permanently deletes current data!

### Step 7: Extract Backup

**Extract to volume:**
```bash
docker run --rm \
  -v $(pwd)/restore_temp:/backup \
  -v vaultwarden-backup-stack_vaultwarden-data:/restore \
  ubuntu:latest \
  tar -xzf /backup/vaultwarden-backup-2024-11-09T02-00-00.tar.gz \
  -C /restore --strip-components=3
```

**Verify extraction:**
```bash
docker run --rm \
  -v vaultwarden-backup-stack_vaultwarden-data:/data \
  ubuntu:latest \
  ls -la /data
```

Should show database files and other Vaultwarden data.

### Step 8: Start Vaultwarden

**Start container:**
```bash
docker compose up -d vaultwarden
```

**Monitor startup:**
```bash
docker compose logs -f vaultwarden
```

Watch for successful initialization messages.

### Step 9: Verify Health

**Check health status:**
```bash
docker compose ps vaultwarden
```

Status should show "healthy".

**Test web access:**
```bash
curl -f http://localhost:8080/alive
# Should return 200 OK
```

**Check admin panel:**

Visit: `https://your-domain.com/admin`

### Step 10: Cleanup

**Remove temporary files:**
```bash
rm -rf restore_temp
```

## Partial Recovery

### Restore Specific Files Only

If you need only specific files (not full restoration):

1. **Download and decrypt backup** (Steps 1-3 above)

2. **Extract specific files:**
   ```bash
   # List contents first
   tar -tzf backup.tar.gz
   
   # Extract specific file
   tar -xzf backup.tar.gz -C ./output \
     backup/vaultwarden-data/db.sqlite3 \
     --strip-components=3
   ```

3. **Copy to volume:**
   ```bash
   docker run --rm \
     -v $(pwd)/output:/source \
     -v vaultwarden-backup-stack_vaultwarden-data:/dest \
     ubuntu:latest \
     cp /source/db.sqlite3 /dest/
   ```

### Database-Only Recovery

For SQLite database recovery without attachments:

1. **Download database file only** (smaller, faster)
2. **Stop Vaultwarden**
3. **Replace database:**
   ```bash
   docker run --rm \
     -v $(pwd):/source \
     -v vaultwarden-backup-stack_vaultwarden-data:/dest \
     ubuntu:latest \
     cp /source/db.sqlite3 /dest/
   ```
4. **Start Vaultwarden**

## Emergency Recovery Scenarios

### Scenario 1: Complete Server Failure

**New server setup:**

1. **Install Docker and Docker Compose**

2. **Clone repository:**
   ```bash
   git clone <repository-url>
   cd vaultwarden-backup-stack
   ```

3. **Configure environment:**
   ```bash
   cp coolify.env .env
   nano .env
   # Set same values as original deployment
   ```

4. **Run restore script:**
   ```bash
   ./scripts/restore.sh
   ```

5. **Verify and reconfigure DNS** if needed

### Scenario 2: Corrupted Database

**Symptoms:**
- Vaultwarden fails to start
- Database errors in logs
- Cannot access web interface

**Recovery:**

1. **Identify last good backup** (before corruption)

2. **Stop Vaultwarden:**
   ```bash
   docker compose stop vaultwarden
   ```

3. **Restore from backup:**
   ```bash
   ./scripts/restore.sh
   # Select backup from before corruption occurred
   ```

4. **Verify data integrity:**
   ```bash
   docker compose logs vaultwarden
   # Check for database errors
   ```

### Scenario 3: Accidental Data Deletion

**Immediate action:**

1. **Stop Vaultwarden immediately:**
   ```bash
   docker compose stop vaultwarden
   ```

2. **Do NOT restart** until restoration complete

3. **Restore latest backup:**
   ```bash
   ./scripts/restore.sh
   ```

### Scenario 4: Lost Encryption Key

**⚠️ Critical Issue**: Without encryption key, backups cannot be restored!

**Prevention:**
- Store encryption key in password manager
- Keep offline backup in secure location
- Document key recovery procedures

**If truly lost:**
- Encrypted backups are unrecoverable
- Must recreate Vaultwarden from scratch
- This is why key backup is critical!

## Verification Procedures

### Post-Restoration Checklist

After any restoration, verify:

- [ ] Vaultwarden container is running and healthy
- [ ] Web interface accessible
- [ ] Admin panel accessible with token
- [ ] User accounts present
- [ ] Passwords accessible
- [ ] File attachments present
- [ ] Organization data intact (if applicable)
- [ ] Two-factor authentication working
- [ ] Mobile apps can sync

### Health Check Commands

**Container status:**
```bash
docker compose ps
```

**Application health:**
```bash
curl -f http://localhost:8080/alive
```

**Database integrity:**
```bash
docker compose exec vaultwarden sqlite3 /data/db.sqlite3 "PRAGMA integrity_check;"
```

**Check logs for errors:**
```bash
docker compose logs --tail=100 vaultwarden | grep -i error
```

## Troubleshooting

### Issue: Restore Script Fails with "Cannot Find Volume"

**Cause:** Volume name mismatch

**Solution:**
```bash
# List volumes
docker volume ls | grep vaultwarden

# Use correct volume name in script
# Edit restore.sh if needed
```

### Issue: Decryption Fails

**Cause:** Wrong encryption key

**Solution:**
- Verify encryption key in `.env`
- Ensure key hasn't been changed since backup
- Try older backups if key was recently rotated

### Issue: Vaultwarden Won't Start After Restore

**Cause:** Database corruption or version mismatch

**Solution:**
```bash
# Check logs
docker compose logs vaultwarden

# Try previous backup
./scripts/restore.sh
# Select older backup

# Check database
docker compose exec vaultwarden sqlite3 /data/db.sqlite3 "PRAGMA integrity_check;"
```

### Issue: Missing Attachments After Restore

**Cause:** Incomplete backup or extraction

**Solution:**
```bash
# Verify backup contents
tar -tzf backup.tar.gz | grep attachments

# Re-extract with verbose output
tar -xzvf backup.tar.gz
```

### Issue: "Permission Denied" Errors

**Cause:** Incorrect file permissions in volume

**Solution:**
```bash
# Fix permissions
docker run --rm \
  -v vaultwarden-backup-stack_vaultwarden-data:/data \
  ubuntu:latest \
  chown -R 1000:1000 /data
```

## Testing Your Recovery Plan

### Regular Recovery Drills

**Monthly:** Test restore process in staging environment

**Quarterly:** Full disaster recovery simulation

### Test Procedure

1. **Create test environment:**
   ```bash
   cp docker-compose.yml docker-compose.test.yml
   # Edit to use different ports/volumes
   ```

2. **Restore to test environment:**
   ```bash
   # Modify restore.sh for test volumes
   ./scripts/restore.sh
   ```

3. **Verify all functionality**

4. **Document any issues**

5. **Update procedures as needed**

## Best Practices

1. **Regular Testing**: Test recovery quarterly
2. **Multiple Backups**: Keep backups in multiple locations
3. **Document Everything**: Maintain recovery runbook
4. **Key Management**: Secure backup of encryption keys
5. **Monitoring**: Alert on backup failures
6. **Versioning**: Maintain multiple backup versions
7. **Automation**: Use automated restore testing
8. **Access Control**: Limit who can perform restores

## Support

For additional help:
- Check Vaultwarden logs: `docker compose logs vaultwarden`
- Review backup logs: `docker compose logs backup`
- Consult [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- Open issue in repository

---

**Remember**: Recovery is only possible with:
- ✅ Valid S3 credentials
- ✅ Correct encryption key
- ✅ Accessible backups
- ✅ Working Docker environment

Keep these secure and accessible!
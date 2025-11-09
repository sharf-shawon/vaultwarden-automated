# Vaultwarden Backup Architecture

This document explains the backup system architecture, data flow, and technical implementation details.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Vaultwarden Stack                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐         ┌──────────────┐                      │
│  │  Vaultwarden │         │  Watchtower  │                      │
│  │   Container  │         │   Container  │                      │
│  │              │         │              │                      │
│  │  Port: 8080  │         │  Updates     │                      │
│  │  Health:     │         │  containers  │                      │
│  │  /alive      │         │  daily       │                      │
│  └──────┬───────┘         └──────────────┘                      │
│         │                                                       │
│         │ Mounts                                                │
│         ↓                                                       │
│  ┌──────────────┐                                               │
│  │  Volume:     │                                               │
│  │  vaultwarden │                                               │
│  │  -data       │                                               │
│  │              │                                               │
│  │  Contents:   │                                               │
│  │  - db.sqlite3│                                               │
│  │  - attachmts │                                               │
│  │  - config    │←────────────────────────┐                     │
│  └──────────────┘                         │                     │
│         │                                 │ Read-only           │
│         │                                 │                     │
│         └─────────────────────────────────┤                     │
│                                           │                     │
│                                    ┌──────┴────────┐            │
│                                    │    Backup     │            │
│                                    │   Container   │            │
│                                    │               │            │
│                                    │  Cron: Daily  │            │
│                                    │  at 2 AM      │            │
│                                    └───────┬───────┘            │
│                                            │                    │
└────────────────────────────────────────────┼────────────────────┘
                                             │
                                             │ Backup Flow
                                             ↓
                            ┌────────────────────────────┐
                            │   Backup Process           │
                            ├────────────────────────────┤
                            │ 1. Create tar.gz archive   │
                            │ 2. Encrypt with GPG        │
                            │ 3. Upload to S3            │
                            │ 4. Verify upload           │
                            │ 5. Prune old backups       │
                            └────────────┬───────────────┘
                                         │
                                         ↓
                            ┌────────────────────────────┐
                            │   S3 Storage               │
                            ├────────────────────────────┤
                            │ Bucket: your-bucket        │
                            │ Path: /vaultwarden-backups │
                            │                            │
                            │ Files:                     │
                            │ - backup-DATE.tar.gz.gpg   │
                            │ - backup-latest.tar.gz.gpg │
                            │                            │
                            │ Retention: 15 days         │
                            │ Versioning: Timestamped    │
                            └────────────────────────────┘
```

## Component Details

### 1. Vaultwarden Container

**Purpose**: Main application server

**Key Features:**
- Health check endpoint: `/alive`
- SQLite database (or PostgreSQL)
- Attachment storage
- User authentication

**Data Storage:**
```
/data/
├── db.sqlite3              # Main database
├── db.sqlite3-wal          # Write-ahead log
├── db.sqlite3-shm          # Shared memory
├── attachments/            # File uploads
│   └── [user_id]/
│       └── [attachment_id]/
├── sends/                  # Send feature data
├── config.json            # Application config
└── rsa_key.*              # Encryption keys
```

**Health Check:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://127.0.0.1:80/alive"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 2. Backup Container

**Purpose**: Automated backup to S3

**Image**: `offen/docker-volume-backup:v2`

**Key Features:**
- Cron-based scheduling
- Volume mounting (read-only)
- GPG encryption
- S3 upload
- Automatic pruning
- Notification support

**Process Flow:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Backup Execution Flow                    │
└─────────────────────────────────────────────────────────────┘

1. Cron Trigger (Daily at 2 AM)
   ↓
2. Pre-Backup Checks
   ├─ Verify S3 connectivity
   ├─ Check encryption key
   └─ Validate volume mount
   ↓
3. Optional: Stop containers (if configured)
   ↓
4. Create Archive
   ├─ Compress: tar + gzip
   ├─ Timestamp: YYYY-MM-DDTHH-MM-SS
   └─ Size: Variable (typically 10-100MB)
   ↓
5. Encrypt Archive
   ├─ Algorithm: AES-256 via GPG
   ├─ Input: backup.tar.gz
   └─ Output: backup.tar.gz.gpg
   ↓
6. Upload to S3
   ├─ Destination: s3://bucket/path/
   ├─ Multipart upload for large files
   └─ Verify checksum
   ↓
7. Create/Update Symlink
   ├─ Link: backup-latest.tar.gz.gpg
   └─ Points to: Most recent backup
   ↓
8. Prune Old Backups
   ├─ Retention: 15 days (configurable)
   ├─ Leeway: 1 minute
   └─ Delete: Backups older than threshold
   ↓
9. Optional: Restart containers (if stopped)
   ↓
10. Send Notifications (if configured)
    ├─ Success: Backup completed
    ├─ Failure: Error details
    └─ Metrics: Size, duration
```

**Environment Configuration:**

```yaml
environment:
  # Scheduling
  - BACKUP_CRON_EXPRESSION=0 2 * * *
  
  # S3 Configuration
  - AWS_S3_BUCKET_NAME=your-bucket
  - AWS_ACCESS_KEY_ID=key
  - AWS_SECRET_ACCESS_KEY=secret
  - AWS_S3_PATH=vaultwarden-backups
  
  # Backup Settings
  - BACKUP_FILENAME=vaultwarden-backup-%Y-%m-%dT%H-%M-%S.tar.gz
  - BACKUP_RETENTION_DAYS=15
  - BACKUP_COMPRESSION=gz
  
  # Security
  - GPG_PASSPHRASE=encryption-key
  
  # Optional Features
  - BACKUP_STOP_CONTAINER_LABEL=backup.stop=true
  - NOTIFICATION_URLS=webhook-url
```

### 3. Watchtower Container

**Purpose**: Automated container updates

**Image**: `containrrr/watchtower:latest`

**Key Features:**
- Automatic image updates
- Rolling restart
- Label-based filtering
- Notification support

**Update Process:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Update Execution Flow                    │
└─────────────────────────────────────────────────────────────┘

1. Poll Interval Trigger (Every 24 hours)
   ↓
2. Check for Updates
   ├─ Query Docker registry
   ├─ Compare image digests
   └─ Identify outdated containers
   ↓
3. Filter Containers
   ├─ Label: com.centurylinklabs.watchtower.enable=true
   ├─ Include: Running containers
   └─ Exclude: Stopped containers
   ↓
4. Rolling Update
   ├─ Pull new image
   ├─ Stop container (graceful)
   ├─ Create new container
   ├─ Start new container
   └─ Wait for health check
   ↓
5. Cleanup
   ├─ Remove old image
   └─ Free disk space
   ↓
6. Send Notification (if configured)
   ├─ Updated: Container name
   ├─ Version: Old → New
   └─ Status: Success/Failure
```

## Data Flow Diagrams

### Backup Data Flow

```
┌──────────────┐
│  Vaultwarden │
│  /data       │
└──────┬───────┘
       │
       │ Read-only mount
       │
       ↓
┌──────────────────┐
│  Backup Process  │
├──────────────────┤
│ 1. Read data     │
│ 2. Create tar.gz │
│ 3. Compress      │
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  GPG Encryption  │
├──────────────────┤
│ Algorithm: AES256│
│ Input: tar.gz    │
│ Output: .gpg     │
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  S3 Upload       │
├──────────────────┤
│ Protocol: HTTPS  │
│ Method: Multipart│
│ Verify: Checksum │
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  S3 Bucket       │
├──────────────────┤
│ ✓ Encrypted file │
│ ✓ Timestamped    │
│ ✓ Versioned      │
└──────────────────┘
```

### Restore Data Flow

```
┌──────────────────┐
│  S3 Bucket       │
├──────────────────┤
│ backup-DATE.gpg  │
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  Download        │
├──────────────────┤
│ Fetch from S3    │
│ Save locally     │
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  GPG Decryption  │
├──────────────────┤
│ Verify passphrase│
│ Decrypt file     │
│ Output: tar.gz   │
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  Extract Archive │
├──────────────────┤
│ Decompress       │
│ Verify integrity │
│ Extract files    │
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  Vaultwarden     │
│  /data           │
├──────────────────┤
│ ✓ Restored DB    │
│ ✓ Restored files │
│ ✓ Ready to start │
└──────────────────┘
```

## Security Architecture

### Encryption

**Backup Encryption:**
```
┌─────────────────────────────────────────────────┐
│            GPG Encryption Process               │
├─────────────────────────────────────────────────┤
│                                                 │
│  Plain Archive                                  │
│  ↓                                              │
│  GPG Symmetric Encryption                       │
│  ├─ Algorithm: AES-256                          │
│  ├─ Cipher: CFB mode                            │
│  ├─ Compression: ZIP                            │
│  └─ Passphrase: User-defined key               │
│  ↓                                              │
│  Encrypted Archive (.gpg)                       │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Data at Rest:**
- Backups: GPG encrypted (AES-256)
- S3 storage: Server-side encryption (optional)
- Local volumes: Filesystem encryption (host-level)

**Data in Transit:**
- S3 uploads: HTTPS/TLS 1.2+
- Container communication: Bridge network (isolated)

### Access Control

**Permission Model:**
```
┌─────────────────────────────────────────────────┐
│              Container Permissions              │
├─────────────────────────────────────────────────┤
│                                                 │
│  Vaultwarden Container                          │
│  ├─ Volume: /data (read-write)                  │
│  └─ Network: bridge                             │
│                                                 │
│  Backup Container                               │
│  ├─ Volume: /data (read-only) ← Least privilege│
│  ├─ Docker socket: /var/run/docker.sock (ro)   │
│  └─ Network: bridge                             │
│                                                 │
│  Watchtower Container                           │
│  ├─ Docker socket: /var/run/docker.sock (ro)   │
│  └─ Network: bridge                             │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Secrets Management:**
1. Environment variables (runtime only)
2. Docker secrets (recommended)
3. Coolify secrets (recommended for Coolify)
4. Never in Git repository
5. Encrypted at rest on host

## Performance Considerations

### Backup Impact

**Resource Usage:**
- CPU: Moderate (compression + encryption)
- Memory: Low (~100-200MB)
- Disk I/O: Moderate (reading data volume)
- Network: Variable (upload speed dependent)

**Timing:**
```
Typical Backup Duration:
├─ Small DB (< 100MB): 1-2 minutes
├─ Medium DB (100MB-1GB): 3-10 minutes
└─ Large DB (> 1GB): 10-30+ minutes

Network upload depends on:
├─ Backup size
├─ Connection speed
└─ S3 endpoint location
```

**Optimization:**
- Run during low-usage periods (2 AM default)
- Use compression (`gz` for balance)
- Consider incremental backups for large datasets
- Multiple CPU cores help with compression

### Storage Requirements

**Local Storage:**
```
Required Space = Data Size × 2 + Temporary

Example for 500MB Vaultwarden data:
├─ Volume data: 500MB
├─ Temporary archive: 150MB (compressed)
├─ Total needed: ~750MB minimum
└─ Recommended: 2GB+ free space
```

**S3 Storage:**
```
Monthly Storage = Backup Size × Retention Days

Example:
├─ Backup size: 150MB (compressed + encrypted)
├─ Retention: 15 days
├─ Total: ~2.25GB stored
└─ Daily new backup replaces oldest
```

## Reliability Features

### Backup Integrity

**Verification Steps:**
1. Checksum verification during upload
2. S3 ETag validation
3. Successful completion confirmation
4. Optional notification on success/failure

**Failure Handling:**
- Automatic retry on transient failures
- Notification on persistent failures
- Backup remains local if upload fails
- Previous backups remain untouched

### High Availability

**Component Redundancy:**
- Vaultwarden: Single instance (stateful)
- Backup: Single instance (scheduled task)
- Watchtower: Single instance (maintenance tool)

**Data Redundancy:**
- Multiple backup versions (15 days)
- S3 versioning (if enabled)
- S3 cross-region replication (optional)
- Multiple S3 destinations (via override)

### Disaster Recovery

**Recovery Time Objective (RTO):**
- Estimated: 15-30 minutes
- Depends on:
  - Backup size
  - Download speed
  - Verification time

**Recovery Point Objective (RPO):**
- Maximum data loss: 24 hours (default)
- Can be reduced to 6 hours with frequent backups
- Near-zero with hourly backups (resource intensive)

## Monitoring and Observability

### Logging

**Log Sources:**
```
Application Logs:
├─ Vaultwarden: /data/vaultwarden.log
├─ Backup: Docker logs
└─ Watchtower: Docker logs

Access via:
docker compose logs -f [service]
```

**Key Events to Monitor:**
- Backup start/completion
- Upload success/failure
- Update detection/application
- Health check failures
- Error conditions

### Metrics

**Backup Metrics:**
- Backup size (trend over time)
- Backup duration
- Upload speed
- Success/failure rate
- Storage usage

**Application Metrics:**
- Container health status
- Resource usage (CPU, memory)
- Disk space usage
- Network traffic

### Alerts

**Recommended Alerts:**
1. Backup failure (critical)
2. Backup older than 48 hours (warning)
3. Disk space < 2GB (warning)
4. Container unhealthy (critical)
5. Update failures (warning)

**Implementation:**
- SMTP notifications
- Webhook notifications
- Monitoring tools integration
- Custom scripts

## Scaling Considerations

### Horizontal Scaling

Vaultwarden is stateful - scaling considerations:
- **Cannot** run multiple instances easily
- **Can** use external database (PostgreSQL)
- **Can** use external storage (S3 for attachments)
- **Should** use load balancer for HA

### Vertical Scaling

Resource requirements by user count:
```
Personal (1-5 users):
├─ CPU: 0.5 cores
├─ RAM: 512MB
└─ Storage: 1GB

Small Team (5-50 users):
├─ CPU: 1 core
├─ RAM: 1GB
└─ Storage: 5GB

Medium Team (50-200 users):
├─ CPU: 2 cores
├─ RAM: 2GB
└─ Storage: 20GB

Large Team (200+ users):
├─ CPU: 4+ cores
├─ RAM: 4GB+
├─ Storage: 50GB+
└─ Database: External PostgreSQL
```

## Technical Specifications

### Supported Platforms

- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **Operating Systems**: Linux (Ubuntu, Debian, CentOS, Alpine)
- **Architectures**: amd64, arm64

### Network Requirements

- **Inbound**: Port 80/443 (via reverse proxy)
- **Outbound**: 
  - S3 endpoint (port 443)
  - Docker registry (port 443)
  - DNS resolution

### Storage Backend Support

- **Primary**: Docker volumes
- **Alternative**: Host bind mounts
- **Database**: SQLite, PostgreSQL, MySQL
- **Attachments**: Local filesystem, S3 (via configuration)

### S3 Compatibility

Tested with:
- ✅ AWS S3
- ✅ DigitalOcean Spaces
- ✅ Backblaze B2
- ✅ Wasabi
- ✅ MinIO
- ✅ Cloudflare R2
- ✅ Most S3-compatible services

---

For implementation details, see other documentation files in this repository.

#!/usr/bin/env bash
# ===================================================
# Hungry Howie's POS - PostgreSQL Backup Script
# ===================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/hungry-howies-pos}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql.gz"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

mkdir -p "${BACKUP_DIR}"

echo "📦 Starting PostgreSQL database backup..."

if [ -n "${DATABASE_URL:-}" ]; then
  pg_dump "${DATABASE_URL}" | gzip > "${BACKUP_FILE}"
else
  PGHOST="${PGHOST:-localhost}"
  PGPORT="${PGPORT:-5432}"
  PGUSER="${PGUSER:-pos_admin}"
  PGDATABASE="${PGDATABASE:-hungry_howies_pos}"

  pg_dump -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" "${PGDATABASE}" | gzip > "${BACKUP_FILE}"
fi

echo "✅ Backup successfully saved to: ${BACKUP_FILE}"

# Cleanup backups older than retention days
find "${BACKUP_DIR}" -name "db_backup_*.sql.gz" -type f -mtime +"${RETENTION_DAYS}" -exec rm -f {} +
echo "🧹 Pruned backups older than ${RETENTION_DAYS} days."

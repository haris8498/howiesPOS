#!/usr/bin/env bash
# ===================================================
# Hungry Howie's POS - PostgreSQL Restore Script
# ===================================================
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path_to_backup_file.sql.gz> [target_database_name]"
  exit 1
fi

BACKUP_FILE="$1"
TARGET_DB="${2:-hungry_howies_pos_restore_test}"

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "❌ Error: Backup file '${BACKUP_FILE}' does not exist!"
  exit 1
fi

echo "⚠️ WARNING: Restoring into database '${TARGET_DB}' from '${BACKUP_FILE}'"
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled."
  exit 0
fi

echo "🔄 Restoring database..."
gunzip -c "${BACKUP_FILE}" | psql -U "${PGUSER:-postgres}" -d "${TARGET_DB}"

echo "✅ Database restore completed successfully into '${TARGET_DB}'."

#!/bin/bash
set -euo pipefail

# Log file

LOGFILE="/var/log/zfs-backup-poolNVME1.log"
mkdir -p "$(dirname "$LOGFILE")"
exec >>"$LOGFILE" 2>&1
echo "===== $(date) starting backup run ====="

trap 'echo "$(date) ERROR on line $LINENO: $BASH_COMMAND (exit=$?)"' ERR


# ============================================================
# Configuration
# ============================================================
SRC="poolNVME1"
DST="poolHDD2/BACKUP/backup_poolNVME1"
SNAP_PREFIX="backup"
RETENTION_DAYS=32
BWLIMIT="50m"          # bandwidth cap (e.g. 20m, 50m, 100m)
LOCKFILE="/var/lock/zfs-backup-poolNVME1.lock"

DATE=$(date +%Y%m%d_%H%M)
SNAP="${SNAP_PREFIX}_${DATE}"

# dependency check
command -v flock >/dev/null 2>&1 || { echo "$(date) flock not found, aborting" >&2; exit 1; }
command -v pv    >/dev/null 2>&1 || { echo "$(date) pv not found (apt install pv), aborting" >&2; exit 1; }
command -v comm   >/dev/null 2>&1 || { echo "$(date) comm not found, aborting" >&2; exit 1; }

# ============================================================
# Lock (prevent overlapping runs)
# ============================================================
exec 9>"${LOCKFILE}" || exit 1
flock -n 9 || { echo "$(date) backup already running, exiting"; exit 0; }

# ============================================================
# Safety checks
# ============================================================

# Skip if a scrub is running
if zpool status | grep -q "scrub in progress"; then
  echo "$(date) scrub in progress, skipping backup"
  exit 0
fi


# Skip if a resilver is running
if zpool status | grep -qi "resilver in progress"; then
  echo "$(date) resilver in progress, skipping backup"
  exit 0
fi

# Ensure source pool is online
if ! zpool status "${SRC%%/*}" | grep -q "^ *state: ONLINE"; then
  echo "$(date) source pool ${SRC%%/*} not ONLINE, aborting backup" >&2
  exit 1
fi

# Ensure destination pool is online
if ! zpool status "${DST%%/*}" | grep -q "^ *state: ONLINE"; then
  echo "$(date) destination pool ${DST%%/*} not ONLINE, aborting backup" >&2
  exit 1
fi

# Ensure destination parent exists (receive will create ${DST})
DST_PARENT="$(dirname "${DST}")"
if ! zfs list -H -o name "${DST_PARENT}" >/dev/null 2>&1; then
  echo "$(date) destination parent dataset ${DST_PARENT} missing, aborting" >&2
  exit 1
fi

DST_AVAIL=$(zfs get -H -o value -p avail "$DST_PARENT")
if [ "$DST_AVAIL" -lt $((500 * 1024 * 1024 * 1024)) ]; then
  echo "$(date) destination has <500GiB free, aborting" >&2
  exit 1
fi

# ============================================================
# Create snapshot
# ============================================================
zfs snapshot -r "${SRC}@${SNAP}"

# ============================================================
# Determine most recent previous backup snapshot
# ============================================================
LAST_SNAP=$(
  comm -12 \
    <(zfs list -H -t snapshot -o name | grep "^${SRC}@${SNAP_PREFIX}_" | sed "s|^${SRC}@||" | sort) \
    <(zfs list -H -t snapshot -o name | grep "^${DST}@${SNAP_PREFIX}_" | sed "s|^${DST}@||" | sort) \
  | tail -1 || true
)

# ============================================================
# Replication
# ============================================================

if [ -n "${LAST_SNAP}" ]; then
  # Incremental send
  zfs send -R -i "${SRC}@${LAST_SNAP}" "${SRC}@${SNAP}" \
    | pv -L "${BWLIMIT}" \
    | zfs receive -u "${DST}"
else
  # First run (full send)
  zfs send -R "${SRC}@${SNAP}" \
    | pv -L "${BWLIMIT}" \
    | zfs receive -u "${DST}"
fi

# ============================================================
# Prune snapshots older than RETENTION_DAYS (source)
# ============================================================
NOW_EPOCH=$(date +%s)

zfs list -t snapshot -o name,creation -s creation \
  | grep "^${SRC}@${SNAP_PREFIX}_" \
  | while read -r SNAPNAME DATE TIME _; do
      SNAP_EPOCH=$(date -d "$DATE $TIME" +%s)
      AGE_DAYS=$(( (NOW_EPOCH - SNAP_EPOCH) / 86400 ))
      if [ "${AGE_DAYS}" -gt "${RETENTION_DAYS}" ]; then
        zfs destroy "${SNAPNAME}"
      fi
    done

# ============================================================
# Prune snapshots older than RETENTION_DAYS (destination)
# ============================================================
zfs list -t snapshot -o name,creation -s creation \
  | grep "^${DST}@${SNAP_PREFIX}_" \
  | while read -r SNAPNAME DATE TIME _; do
      SNAP_EPOCH=$(date -d "$DATE $TIME" +%s)
      AGE_DAYS=$(( (NOW_EPOCH - SNAP_EPOCH) / 86400 ))
      if [ "${AGE_DAYS}" -gt "${RETENTION_DAYS}" ]; then
        zfs destroy "${SNAPNAME}"
      fi
    done

echo "===== $(date) backup run completed successfully ====="

exit 0


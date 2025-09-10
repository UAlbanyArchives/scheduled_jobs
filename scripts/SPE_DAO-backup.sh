#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/SPE_DAO-backup.log"
mkdir -p "$(dirname "$LOGFILE")"

echo "SPE_DAO backup started at $(date)" >> "$LOGFILE"

SRC="/media/Library/SPE_DAO/"
DEST="/media/Masters/Archives/SPE_DAO-backup"
TODAY=$(date +%Y%m%d)

NEW_BACKUP="$DEST/backup-$TODAY"
mkdir -p "$NEW_BACKUP"

# Rsync (full copy on SMB)
rsync -a --delete "$SRC" "$NEW_BACKUP"

# --- Cleanup: keep only the 2 newest backups ---
BACKUPS=( $(ls -1d "$DEST"/backup-* 2>/dev/null | sort -r) )

COUNT=${#BACKUPS[@]}

if [ $COUNT -gt 2 ]; then
    for i in $(seq 3 $COUNT); do
        OLD=${BACKUPS[$((i-1))]}
        echo "Removing old backup $OLD..." | tee -a "$LOGFILE"
        rm -rf "$OLD"
    done
fi

echo "SPE_DAO backup finished at $(date)" >> "$LOGFILE"

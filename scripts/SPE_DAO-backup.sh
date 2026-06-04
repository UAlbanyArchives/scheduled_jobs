#!/bin/bash
set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "SPE_DAO backup started"

SRC="/media/Library/SPE_DAO/"
DEST="/media/Masters/Archives/SPE_DAO-backup"
TODAY=$(date +%Y%m%d)

NEW_BACKUP="$DEST/backup-$TODAY"
mkdir -p "$NEW_BACKUP"

# Rsync (full copy on SMB)
rsync -a --delete "$SRC" "$NEW_BACKUP"

# --- Cleanup: keep only the 2 newest backups ---
mapfile -t BACKUPS < <(find "$DEST" -maxdepth 1 -mindepth 1 -type d -name 'backup-*' | sort -r)

COUNT=${#BACKUPS[@]}

if [ $COUNT -gt 2 ]; then
    for i in $(seq 3 $COUNT); do
        OLD=${BACKUPS[$((i-1))]}
        log "Removing old backup $OLD"
        rm -rf "$OLD"
    done
fi

log "SPE_DAO backup finished"

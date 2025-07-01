#!/bin/bash

echo "SPE_DAO backup started at $(date)" >> /app/logs/job.log

SRC="/media/Library/SPE_DAO/"
DEST="/media/Masters/Archives/SPE_DAO-backup"
TODAY=$(date +%Y%m%d)

# Create new backup directory
NEW_BACKUP="$DEST/backup-$TODAY"

# If a previous backup exists, copy it with hard links to save space
LAST_BACKUP=$(ls -1d $DEST/backup-* 2>/dev/null | sort | tail -1)

if [ -n "$LAST_BACKUP" ]; then
    echo "Creating hard-linked copy from $LAST_BACKUP..."
    cp -al "$LAST_BACKUP" "$NEW_BACKUP"
else
    echo "No previous backup found; creating fresh snapshot..."
    mkdir -p "$NEW_BACKUP"
fi

# Sync source into new backup
rsync -a --delete "$SRC" "$NEW_BACKUP"

# Update weekly backup symlink
ln -sfn "backup-$TODAY" "$DEST/backup-weekly"

# If today is the first of the month, update monthly backup symlink
if [ "$(date +%d)" == "01" ]; then
    ln -sfn "backup-$TODAY" "$DEST/backup-monthly"
fi

# Cleanup old dated backups not pointed to by weekly/monthly symlinks
for dir in "$DEST"/backup-[0-9]*; do
    [[ "$dir" == "$DEST"/$(readlink -f "$DEST"/backup-weekly) ]] && continue
    [[ "$dir" == "$DEST"/$(readlink -f "$DEST"/backup-monthly) ]] && continue
    echo "Removing old backup $dir..."
    rm -rf "$dir"
done

#!/bin/bash
set -euo pipefail

# Usage: ./track_disk_usage.sh
# Logs disk usage for /media/Masters and /media/Library to TSV files.

# Define which disk mount points to track
DISKS=("Masters" "Library")

# Output base directory
OUT_DIR="/logs/DiskSpace"

# Create output directory if it doesn't exist
mkdir -p "$OUT_DIR"

# Capture timestamp
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

#echo "Starting disk usage logging at $DATE"

for DISK in "${DISKS[@]}"; do
    MOUNT_PATH="/media/$DISK"
    OUTPUT_FILE="$OUT_DIR/${DISK}.tsv"

    echo "Checking $MOUNT_PATH"

    if mountpoint -q "$MOUNT_PATH"; then
        START=$(df -h "$MOUNT_PATH" | awk 'NR==2 {printf "%s\t%s\t%s\t%s\t%s", $1, $2, $3, $4, $5}')
        END=$(df "$MOUNT_PATH" --output=size,used,avail | awk 'NR==2 {printf "%s\t%s\t%s", $1, $2, $3}')
        echo -e "$DATE\t$START\t$END" >> "$OUTPUT_FILE"
        echo "Logged disk usage to $OUTPUT_FILE"
    else
        echo "Warning: $MOUNT_PATH is not mounted or does not exist" >&2
    fi
done

echo "Disk usage logging complete at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

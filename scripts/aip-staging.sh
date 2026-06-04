#!/bin/bash
set -euo pipefail

STAGING_ROOT="/media/Masters/Archives/AIP_staging"
B2_ROOT="b2:AIP-storage"
RCLONE_CONFIG_FILE="${RCLONE_CONFIG_FILE:-/root/.config/rclone/rclone.conf}"

if [ ! -f "$RCLONE_CONFIG_FILE" ]; then
  echo "ERROR: rclone config not found at $RCLONE_CONFIG_FILE"
  echo "Set RCLONE_CONFIG_FILE or mount ./rclone to /root/.config/rclone in docker-compose-staging.yml"
  exit 1
fi

if ! rclone listremotes --config "$RCLONE_CONFIG_FILE" | grep -Fxq "b2:"; then
  echo "ERROR: remote 'b2' not found in $RCLONE_CONFIG_FILE"
  exit 1
fi

echo "AIP staging upload started at $(date '+%Y-%m-%d %H:%M:%S')"

RCLONE_FLAGS=(
  --config "$RCLONE_CONFIG_FILE"
  --transfers 4
  --checkers 8
  --bwlimit 40M
  --tpslimit 10
  --fast-list
  --stats 30s
  --retries 3
  --low-level-retries 10
  --log-level NOTICE
)

for collection in "$STAGING_ROOT"/*; do
  [ -d "$collection" ] || continue
  col_id=$(basename "$collection")

  for package in "$collection"/*; do
    [ -d "$package" ] || continue
    pkg_id=$(basename "$package")

    SRC="$package"
    DEST="$B2_ROOT/$col_id/$pkg_id"

    echo "  Processing $col_id/$pkg_id"
    echo "    Started at $(date '+%Y-%m-%d %H:%M:%S')"

    # Check whether pkg_id exists as a directory directly under the collection.
    if rclone lsf "$B2_ROOT/$col_id" --dirs-only --max-depth 1 | grep -Fxq "$pkg_id/"; then
      echo "    Package already exists in B2 — skipping (local copy retained)"
      continue
    fi

    # Copy (polite/background characteristics are already in flags)
    if ! rclone copy "$SRC" "$DEST" "${RCLONE_FLAGS[@]}"; then
      echo "    ERROR: Copy failed for $col_id/$pkg_id; retaining local package and continuing"
      continue
    fi

    # Verify before delete
    if ! rclone check "$SRC" "$DEST" --checksum; then
      echo "    ERROR: Verification failed for $col_id/$pkg_id; retaining local package and continuing"
      continue
    fi

    echo "    Verified upload; removing local package"
    if ! rm -rf "$SRC"; then
      echo "    ERROR: Could not remove local package $SRC; continuing to next package"
      continue
    fi

    echo "    Finished at $(date '+%Y-%m-%d %H:%M:%S')"
  done

  # Remove empty collection directories
  if [ -d "$collection" ] && [ -z "$(ls -A "$collection")" ]; then
    echo "  Removing empty collection directory $collection"
    if ! rmdir "$collection"; then
      echo "  WARNING: Could not remove collection directory $collection"
    fi
  fi
done

echo "  AIP staging upload finished at $(date '+%Y-%m-%d %H:%M:%S')"
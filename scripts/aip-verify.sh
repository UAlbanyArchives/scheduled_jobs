#!/bin/bash
set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

format_duration() {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))
  printf '%02dh %02dm %02ds' "$hours" "$minutes" "$seconds"
}

SOURCE_ROOT="${SOURCE_ROOT:-/media/Masters/Archives/AIP}"
B2_ROOT="${B2_ROOT:-b2:AIP-storage}"
RCLONE_CONFIG_FILE="${RCLONE_CONFIG_FILE:-/root/.config/rclone/rclone.conf}"
VERIFY_MODE="${VERIFY_MODE:-checksum}"
TARGET_COLLECTION="${1:-}"

if [ ! -f "$RCLONE_CONFIG_FILE" ]; then
  log "ERROR: rclone config not found at $RCLONE_CONFIG_FILE"
  log "Set RCLONE_CONFIG_FILE or mount ./rclone to /root/.config/rclone"
  exit 1
fi

if ! rclone listremotes --config "$RCLONE_CONFIG_FILE" | grep -Fxq "b2:"; then
  log "ERROR: remote 'b2' not found in $RCLONE_CONFIG_FILE"
  exit 1
fi

case "$VERIFY_MODE" in
  checksum)
    VERIFY_FLAG="--checksum"
    ;;
  size)
    VERIFY_FLAG="--size-only"
    ;;
  *)
    log "ERROR: VERIFY_MODE must be 'checksum' or 'size' (got '$VERIFY_MODE')"
    exit 1
    ;;
esac

if [ -n "$TARGET_COLLECTION" ]; then
  COLLECTION_GLOB="$SOURCE_ROOT/$TARGET_COLLECTION"
else
  COLLECTION_GLOB="$SOURCE_ROOT/*"
fi

RCLONE_FLAGS=(
  --config "$RCLONE_CONFIG_FILE"
  --checkers 8
  --fast-list
  --stats 60s
  --retries 3
  --low-level-retries 10
  --log-level NOTICE
)

START_EPOCH=$(date +%s)
TOTAL=0
PASSED=0
FAILED=0

log "AIP verification started"
log "Source root: $SOURCE_ROOT"
log "Destination root: $B2_ROOT"
log "Mode: $VERIFY_MODE"

for collection in $COLLECTION_GLOB; do
  [ -d "$collection" ] || continue
  col_id=$(basename "$collection")
  log "Collection $col_id"

  for package in "$collection"/*; do
    [ -d "$package" ] || continue
    pkg_id=$(basename "$package")
    TOTAL=$((TOTAL + 1))

    SRC="$package"
    DEST="$B2_ROOT/$col_id/$pkg_id"

    log "  Checking $col_id/$pkg_id"
    if rclone check "$SRC" "$DEST" "$VERIFY_FLAG" "${RCLONE_FLAGS[@]}"; then
      PASSED=$((PASSED + 1))
    else
      FAILED=$((FAILED + 1))
      log "  ERROR: Verification failed for $col_id/$pkg_id"
    fi
  done
done

END_EPOCH=$(date +%s)
ELAPSED_SECONDS=$((END_EPOCH - START_EPOCH))

log "AIP verification finished"
log "Summary: total=$TOTAL passed=$PASSED failed=$FAILED"
log "Duration: $(format_duration "$ELAPSED_SECONDS")"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi

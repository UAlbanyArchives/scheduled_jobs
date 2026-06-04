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

log "SPE_DAO backup started"
START_EPOCH=$(date +%s)

SRC="/media/Library/SPE_DAO/"
DEST_ROOT="b2-dao:"
TODAY=$(date +%Y%m%d)
CURRENT_PATH="${DEST_ROOT}current"
HISTORY_ROOT="${DEST_ROOT}history"
HISTORY_PATH="${HISTORY_ROOT}/$TODAY"
HISTORY_KEEP="${HISTORY_KEEP:-6}"
RCLONE_CONFIG_FILE="${RCLONE_CONFIG_FILE:-/root/.config/rclone/rclone.conf}"

if ! [[ "$HISTORY_KEEP" =~ ^[0-9]+$ ]]; then
    log "ERROR: HISTORY_KEEP must be a non-negative integer (got '$HISTORY_KEEP')"
    exit 1
fi

if [ ! -f "$RCLONE_CONFIG_FILE" ]; then
    log "ERROR: rclone config not found at $RCLONE_CONFIG_FILE"
    log "Set RCLONE_CONFIG_FILE or mount ./rclone to /root/.config/rclone in docker-compose-staging.yml"
    exit 1
fi

if ! rclone listremotes --config "$RCLONE_CONFIG_FILE" | grep -Fxq "b2-dao:"; then
    log "ERROR: remote 'b2-dao' not found in $RCLONE_CONFIG_FILE"
    exit 1
fi

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

# Incremental mirror: current is a full latest copy, history stores replaced/deleted versions.
rclone sync "$SRC" "$CURRENT_PATH" --backup-dir "$HISTORY_PATH" "${RCLONE_FLAGS[@]}"

# --- Cleanup: keep only the newest history directories ---
mapfile -t HISTORY_DIRS < <(
    rclone lsf "$HISTORY_ROOT" "${RCLONE_FLAGS[@]}" --dirs-only --max-depth 1 \
        | grep -E '^[0-9]{8}/$' \
        | sed 's:/$::' \
        | sort -r || true
)

COUNT=${#HISTORY_DIRS[@]}

if [ "$COUNT" -gt "$HISTORY_KEEP" ]; then
    for ((i=HISTORY_KEEP; i<COUNT; i++)); do
        OLD=${HISTORY_DIRS[$i]}
        log "Removing old history directory $OLD"
        rclone purge "$HISTORY_ROOT/$OLD" "${RCLONE_FLAGS[@]}"
    done
fi

END_EPOCH=$(date +%s)
ELAPSED_SECONDS=$((END_EPOCH - START_EPOCH))
log "SPE_DAO backup finished (duration: $(format_duration "$ELAPSED_SECONDS"))"

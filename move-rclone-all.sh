#!/bin/bash
set -euo pipefail

SOURCE_BASE="/media/Masters/Archives/AIP"
DEST_BASE="b2:AIP-storage"
LOG_BASE="/media/Library/SPE_Automated/rclone"
COMPOSE_FILE="$HOME/scheduled_jobs/docker-compose.yml"
MAIN_LOG="$LOG_BASE/main-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_BASE"

echo "Main log: $MAIN_LOG"
echo "Started at $(date)" | tee -a "$MAIN_LOG"
echo "Copying entire AIP directory to B2" | tee -a "$MAIN_LOG"

docker compose -f "$COMPOSE_FILE" run --rm -T jobs bash -c "
  rclone copy \"$SOURCE_BASE\" \"$DEST_BASE\" \
    --transfers 16 \
    --checkers 32 \
    --fast-list \
    --log-file \"$MAIN_LOG\" \
    --log-level INFO \
    --stats 30s \
    --retries 3 \
    --low-level-retries 10 \
  && echo \"Done.\" >> \"$MAIN_LOG\"
"

echo "$(date): Upload complete." | tee -a "$MAIN_LOG"

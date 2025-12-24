#!/bin/bash
set -euo pipefail

SOURCE_BASE="/media/Masters/Archives/AIP"
DEST_BASE="b2:AIP-storage"
LOG_BASE="/media/Library/SPE_Automated/rclone"
COMPOSE_FILE="$HOME/scheduled_jobs/docker-compose.yml"
MAX_JOBS=2
MAIN_LOG="$LOG_BASE/main-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_BASE"

echo "Main log: $MAIN_LOG"
echo "Started at $(date)" | tee -a "$MAIN_LOG"

running_jobs=0

# Use a for loop to start jobs in order
for dir in "$SOURCE_BASE"/*; do
  [ -d "$dir" ] || continue
  folder="$(basename "$dir")"
  log_file="$LOG_BASE/initial-$folder.log"
  mkdir -p "$(dirname "$log_file")"

  echo "$(date): Starting rclone upload for $folder" | tee -a "$MAIN_LOG"

  # Start job in background safely
  (
    docker compose -f "$COMPOSE_FILE" run --rm -T jobs bash -c "
      rclone copy \"$dir\" \"$DEST_BASE/$folder\" \
        --transfers 16 \
        --checkers 32 \
        --fast-list \
        --log-file \"$log_file\" \
        --log-level INFO \
        --stats 30s \
        --retries 3 \
        --low-level-retries 10 \
      && echo \"Done.\" >> \"$log_file\"
    "
  ) &

  ((running_jobs++))

  # Wait if we hit MAX_JOBS
  if (( running_jobs >= MAX_JOBS )); then
    wait -n
    ((running_jobs--))
  fi
done

# Wait for any remaining jobs
wait
echo "$(date): All uploads complete." | tee -a "$MAIN_LOG"

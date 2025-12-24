#!/bin/bash
set -euo pipefail

SOURCE_BASE="/media/Masters/Archives/AIP"
DEST_BASE="b2:AIP-storage"
LOG_BASE="/media/Library/SPE_Automated/rclone"
COMPOSE_FILE="$HOME/scheduled_jobs/docker-compose.yml"

MAX_JOBS=2  # Adjust concurrency based on your VM capacity

mkdir -p "$LOG_BASE"

running_jobs=0

for dir in "$SOURCE_BASE"/*; do
  [ -d "$dir" ] || continue
  folder="$(basename "$dir")"

  # ---- collection filtering ----
  if [[ "$folder" =~ ^apap([0-9]{3})$ ]]; then
    num="${BASH_REMATCH[1]}"
    (( num >= 102 )) || continue
    (( num != 301 )) || continue
  elif [[ "$folder" =~ ^ua([0-9]{3})$ ]]; then
    [[ "$folder" == "ua390" ]] && continue
  elif [[ "$folder" =~ ^(ger|mss) ]]; then
    :
  else
    continue
  fi

  log_file="/logs/rclone/initial-$folder.log"

  echo "Starting rclone upload for $folder"

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
  " &

  ((running_jobs++))

  # Wait if we reach max concurrency
  if (( running_jobs >= MAX_JOBS )); then
    wait -n
    ((running_jobs--))
  fi

done

# Wait for any remaining jobs
wait

echo "All uploads complete."

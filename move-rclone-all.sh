#!/bin/bash
set -euo pipefail

SOURCE_BASE="/media/Masters/Archives/AIP"
DEST_BASE="b2:AIP-storage"
LOG_BASE="/logs/rclone"

COMPOSE_FILE="$HOME/scheduled_jobs/docker-compose.yml"

mkdir -p "$LOG_BASE"

for dir in "$SOURCE_BASE"/*; do
  [ -d "$dir" ] || continue

  folder="$(basename "$dir")"

  # ---- collection filtering rules ----

  case "$folder" in
    apap[0-9][0-9][0-9])
      num="${folder#apap}"
      # apap102+ only
      if (( num < 102 )); then
        continue
      fi
      # exclude apap301
      if (( num == 301 )); then
        continue
      fi
      ;;
    ger*|mss*)
      ;;
    ua[0-9][0-9][0-9])
      # exclude ua390
      if [[ "$folder" == "ua390" ]]; then
        continue
      fi
      ;;
    *)
      continue
      ;;
  esac

  log_file="$LOG_BASE/initial-$folder.log"

  echo "Starting rclone upload for $folder"
  echo "Logging to $log_file"

  docker compose -f "$COMPOSE_FILE" run --rm -T jobs \
    rclone copy "$dir" "$DEST_BASE/$folder" \
      --transfers 16 \
      --checkers 32 \
      --fast-list \
      --log-file "$log_file" \
      --log-level INFO \
      --stats 30s \
      --retries 3 \
      --low-level-retries 10

  rc=$?

  if [ "$rc" -eq 0 ]; then
    echo "Done." | tee -a "$log_file"
  else
    echo "FAILED (exit code $rc)" | tee -a "$log_file"
  fi

done

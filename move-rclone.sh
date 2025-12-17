#!/bin/bash

folder=$1

if [ -z "$folder" ]; then
  echo "Usage: move-rclone <folder>"
  exit 1
fi

docker compose -f ~/scheduled_jobs/docker-compose.yml run --rm -T jobs \
  rclone copy "/media/Masters/Archives/AIP/$folder" "b2:AIP-storage/$folder" \
  --transfers 16 \
  --checkers 32 \
  --fast-list \
  --log-file "/logs/rclone/initial-$folder.log" \
  --log-level INFO \
  --stats 30s \
  --retries 3 \
  --low-level-retries 10 &

echo "Started rclone upload for $folder (logs: SPE_Automated/rclone/initial-$folder.log)"

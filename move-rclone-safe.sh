#!/bin/bash

folder=$1

if [ -z "$folder" ]; then
  echo "Usage: move-rclone <folder>"
  exit 1
fi

nice -n 10 ionice -c2 -n7 \
docker compose -f ~/scheduled_jobs/docker-compose.yml run --rm -T jobs \
  rclone copy "/media/Masters/Archives/AIP/$folder" "b2:AIP-storage/$folder" \
  --transfers 4 \
  --checkers 8 \
  --bwlimit 40M \
  --tpslimit 10 \
  --fast-list \
  --log-file "/logs/rclone/initial-$folder.log" \
  --log-level INFO \
  --stats 30s \
  --retries 3 \
  --low-level-retries 10 &

echo "Started rclone upload for $folder (logs: SPE_Automated/rclone/initial-$folder.log)"

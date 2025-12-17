#!/bin/bash

# usage: move-rclone <folder>
folder=$1

if [ -z "$folder" ]; then
  echo "Usage: move-rclone <folder>"
  exit 1
fi

docker compose -f ~/scheduled_jobs/docker-compose.yml run -d jobs rclone \
  copy /media/Masters/Archives/AIP/$folder b2:/$folder \
  --transfers 16 \
  --checkers 32 \
  --fast-list \
  --log-file /logs/rclone/inital-$folder.log \
  --log-level INFO \
  --stats 30s \
  --retries 3 \
  --low-level-retries 10

echo "Started rclone upload for $folder (logs: /logs/rclone/inital-$folder.log)"

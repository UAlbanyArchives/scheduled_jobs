#!/bin/bash
set -euo pipefail

SOURCE_BASE="/media/Masters/Archives/AIP"
DEST_BASE="b2:AIP-storage"
COMPOSE_FILE="$HOME/scheduled_jobs/docker-compose.yml"
HOST_LOG_DIR="/media/Library/SPE_Automated/rclone"
CONTAINER_LOG_DIR="/logs/rclone"
PID_FILE="$HOST_LOG_DIR/move-rclone-safe.pid"

folder="${1:-}"
stamp="$(date +%Y%m%d-%H%M%S)"

if [ -n "$folder" ]; then
  src="$SOURCE_BASE/$folder"
  dest="$DEST_BASE/$folder"
  log_tag="$folder"
else
  src="$SOURCE_BASE"
  dest="$DEST_BASE"
  log_tag="all"
fi

if [ -f "$PID_FILE" ]; then
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    echo "An upload is already running with PID $old_pid."
    echo "If that process is stale, remove $PID_FILE and retry."
    exit 1
  fi
fi

mkdir -p "$HOST_LOG_DIR"

run_log="$HOST_LOG_DIR/catchup-${log_tag}-${stamp}.log"
launcher_log="$HOST_LOG_DIR/catchup-${log_tag}-${stamp}-launcher.log"
container_run_log="$CONTAINER_LOG_DIR/catchup-${log_tag}-${stamp}.log"

{
  echo "Launcher started at $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Source: $src"
  echo "Destination: $dest"
  echo "Compose file: $COMPOSE_FILE"
  echo "Host log: $run_log"
  echo "Container log: $container_run_log"
} >> "$launcher_log"

nohup bash -lc "
  set -euo pipefail
  echo \"Started at \\$(date '+%Y-%m-%d %H:%M:%S')\" >> '$launcher_log'
  nice -n 10 ionice -c2 -n7 \
    docker compose -f '$COMPOSE_FILE' run --rm -T jobs \
      rclone copy '$src' '$dest' \
      --ignore-existing \
      --transfers 4 \
      --checkers 8 \
      --bwlimit 40M \
      --tpslimit 10 \
      --fast-list \
      --log-file '$container_run_log' \
      --log-level INFO \
      --stats 30s \
      --retries 3 \
      --low-level-retries 10
  rc=\\$?
  echo \"Finished at \\$(date '+%Y-%m-%d %H:%M:%S') with exit code \\$rc\" >> '$launcher_log'
  rm -f '$PID_FILE'
  exit \\$rc
    " >> "$launcher_log" 2>&1 &

new_pid=$!
echo "$new_pid" > "$PID_FILE"

echo "Started background rclone catchup with PID $new_pid"
echo "Source: $src"
echo "Destination: $dest"
echo "Rclone log: $run_log"
echo "Launcher log: $launcher_log"

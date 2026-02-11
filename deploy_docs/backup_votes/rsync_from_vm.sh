#!/usr/bin/env bash
set -euo pipefail

# ---------- configuration ----------
# IMPORTANT: Since rrsync on the server is locked to the app_env folder, 
# here the source path is only "/"
SRC_PATH="/"
BASE_DST="$HOME/mutation_voting_backup"
LOG_DIR="$HOME/log"

# Import notify_slack.sh (which also loads the .env)
source "$(dirname "$0")/notify_slack.sh"

# ---------- per-run identifiers ----------
RUN_ID="$(date +'%Y-%m-%dT%H-%M-%S')"

DST_PATH="$BASE_DST/$RUN_ID"
LOG_FILE="$LOG_DIR/rsync_from_vm_$RUN_ID.log"

# ---------- prepare filesystem ----------
mkdir -p "$DST_PATH"
mkdir -p "$LOG_DIR"

# ---------- logging ----------
exec >>"$LOG_FILE" 2>&1

# Create/Update the symlink to the current log
ln -sfn "$LOG_FILE" "$LOG_DIR/latest_rsync_from_vm.log"

log(){ printf '%s [%s] %s\n' "$(date -Is)" "$RUN_ID" "$*"; }

# ---------- traps ----------
trap '
  last_log=$(tail -n 5 "$LOG_FILE");
  notify_slack "failure" "Run ID: \`${RUN_ID}\`Log Tail -n 5:\`\`\`${last_log}\`\`\`";
  exit 1
' ERR

# ---------- execution ----------

# Avoiding shared resource bottlenecks
# Wait between 1 and 60 seconds before starting
delay=$(( 1 + RANDOM % 60 ))
log "Adding random jitter: sleeping for ${delay}s..."
sleep "$delay"

log "Starting rsync..."
log "Destination: $DST_PATH"

rsync -aHAX --numeric-ids --stats "denbi:${SRC_PATH}" "${DST_PATH}"

# symlink to the latest backup
ln -sfn "$DST_PATH" "$BASE_DST/latest"
date -Is > "$BASE_DST/LAST_SUCCESS"
log "Finished rsync OK"

# Send Success Notification
size=$(du -sh "$DST_PATH" | awk '{print $1}')
notify_slack "success" "Run ID: \`${RUN_ID}\` Size: \`${size}\`"
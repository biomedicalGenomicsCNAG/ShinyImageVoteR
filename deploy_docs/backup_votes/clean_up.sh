#!/usr/bin/env bash
set -euo pipefail

# ---------- configuration ----------
BASE_DST="$HOME/mutation_voting_backup"
LOG_DIR="$HOME/log"

# ---------- usage check ----------
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <start_date> <end_date>"
    echo "Example: $0 2026-01-01 2026-01-31"
    exit 1
fi

START_DATE=$(date -d "$1" +%s)
END_DATE=$(date -d "$2" +%s)

# Identify the REAL paths currently pointed to by "latest" symlinks
PROTECTED_BACKUP=$(readlink -f "$BASE_DST/latest" || echo "NONE")
PROTECTED_LOG=$(readlink -f "$LOG_DIR/latest.log" || echo "NONE")

log(){ printf '%s [CLEANUP] %s\n' "$(date -Is)" "$*"; }

cleanup_items() {
    local dir=$1
    local pattern=$2
    local protected_path=$3
    
    log "Checking $dir for items between $1 and $2..."

    for item in "$dir"/$pattern; do
        [ -e "$item" ] || continue
        
        # Get absolute path to compare against protected path
        full_item_path=$(readlink -f "$item")

        # 1. Protection Check: Is this the 'latest' folder/file?
        if [[ "$full_item_path" == "$protected_path" ]]; then
            log "Skipping (PROTECTED): $(basename "$item")"
            continue
        fi

        # 2. Date Check
        filename=$(basename "$item")
        date_str=$(echo "$filename" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -n 1)
        
        # Ensure we found a date string before processing
        if [ -z "$date_str" ]; then continue; fi

        item_date=$(date -d "$date_str" +%s)

        if [[ "$item_date" -ge "$START_DATE" && "$item_date" -le "$END_DATE" ]]; then
            log "Deleting: $filename"
            rm -rf "$item"
        fi
    done
}

# ---------- execution ----------
# 1. Clean up Backups (Folders) - Protecting the 'latest' link destination
cleanup_items "$BASE_DST" "202*" "$PROTECTED_BACKUP"

# 2. Clean up Logs (Files) - Protecting the 'latest.log' link destination
cleanup_items "$LOG_DIR" "rsync_from_vm_202*.log" "$PROTECTED_LOG"

log "Cleanup complete."
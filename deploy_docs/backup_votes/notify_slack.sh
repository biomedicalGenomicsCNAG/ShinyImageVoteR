#!/usr/bin/env bash

# Find the directory where this script lives
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env file if it exists
if [ -f "$SRC_DIR/.env" ]; then
    # We use 'grep -v' to skip comments and 'export' to make variables available
    export $(grep -v '^#' "$SRC_DIR/.env" | xargs)
else
    # Fallback/Safety check: you'll see this in your log if the .env is missing
    echo "[ERROR] .env file not found in $SRC_DIR" >&2
fi

# Function to send JSON payloads to Slack safely using Python3
# Usage: notify_slack "success" "Host: denbi - Backup OK"
notify_slack() {
    local status="$1"
    local message_body="$2"
    local icon="✅"
    
    if [[ "$status" == "failure" ]]; then
        icon="🚨"
    fi

    # Construct the final text
    local full_msg="${icon} *${status^^}* ${message_body}"

    # Use Python3 to safely JSON-encode the payload
    local payload
    payload=$(python3 -c 'import json,sys; print(json.dumps({"text": sys.argv[1]}))' "$full_msg")

    # Send the payload and log the response headers/body
    log "Sending $status notification to Slack..."
    curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
    printf '\n'
}
#!/usr/bin/env bash
# ActivityWatch Watchdog - Auto-restart after suspend/resume issues
# Similar to hyprshell-watchdog, monitors and restarts ActivityWatch services if they fail

LOG_FILE="/tmp/aw-watchdog.log"
CHECK_INTERVAL=120  # Check every 2 minutes

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

check_service() {
    local service=$1
    if ! systemctl --user is-active --quiet "$service"; then
        log "WARNING: $service is not active, restarting..."
        systemctl --user restart "$service"
        sleep 2
        if systemctl --user is-active --quiet "$service"; then
            log "OK: $service restarted successfully"
        else
            log "ERROR: Failed to restart $service"
        fi
    fi
}

check_api() {
    # Check if ActivityWatch API is responding
    if ! curl -sf http://localhost:5600/api/0/buckets/ > /dev/null 2>&1; then
        log "WARNING: ActivityWatch API not responding, restarting server..."
        systemctl --user restart aw-server
        sleep 3
    fi
}

check_bucket_updates() {
    # Check if buckets are being updated (data is flowing)
    local window_bucket="aw-watcher-window_$(hostname)"
    local last_update=$(curl -s "http://localhost:5600/api/0/buckets/$window_bucket" 2>/dev/null | jq -r '.last_updated // empty')

    if [ -n "$last_update" ]; then
        # Calculate time since last update
        local last_update_ts=$(date -d "$last_update" +%s 2>/dev/null || echo 0)
        local now_ts=$(date +%s)
        local diff=$((now_ts - last_update_ts))

        # If no updates in 5 minutes and we're active, something's wrong
        if [ $diff -gt 300 ]; then
            log "WARNING: No window updates in $((diff/60)) minutes, restarting awatcher..."
            systemctl --user restart aw-awatcher
            sleep 2
        fi
    fi
}

log "ActivityWatch Watchdog started"

while true; do
    # Check core services
    check_service "aw-server"
    check_service "aw-awatcher"

    # Check API responsiveness
    check_api

    # Check if data is flowing (optional, more aggressive)
    # check_bucket_updates

    sleep $CHECK_INTERVAL
done

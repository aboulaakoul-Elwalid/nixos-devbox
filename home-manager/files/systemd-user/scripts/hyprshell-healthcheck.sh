#!/usr/bin/env bash
# Hyprshell health check - restarts hyprshell if IPC communication fails
# Only checks if hyprshell has been running for at least 30 seconds

set -euo pipefail

log() {
    printf '%s hyprshell-healthcheck: %s\n' "$(date --iso-8601=seconds)" "$*" >&2
}

# Check if hyprshell is running at all
HYPRSHELL_PID=$(pgrep -f "hyprshell run" 2>/dev/null | head -1) || true
if [[ -z "$HYPRSHELL_PID" ]]; then
    log "Hyprshell not running, systemd should handle this"
    exit 0
fi

# Check how long hyprshell has been running - don't restart if it just started
HYPRSHELL_START=$(stat -c %Y /proc/"$HYPRSHELL_PID" 2>/dev/null) || {
    log "Could not get hyprshell start time"
    exit 0
}
NOW=$(date +%s)
UPTIME=$((NOW - HYPRSHELL_START))

if [[ $UPTIME -lt 30 ]]; then
    log "Hyprshell only running for ${UPTIME}s, giving it time to initialize"
    exit 0
fi

# Check if hyprctl can communicate (this uses HYPRLAND_INSTANCE_SIGNATURE from environment)
if ! timeout 3 hyprctl activewindow &>/dev/null; then
    log "Hyprland IPC not responsive after ${UPTIME}s uptime, restarting hyprshell"
    systemctl --user restart hyprshell.service
    exit 0
fi

# Ensure hyprshell plugin stays loaded after hypr reload events.
if ! hyprctl plugins list 2>/dev/null | grep -q "hyprshell-hyprland-plugin"; then
    if [[ -f /tmp/hyprshell.so ]]; then
        if hyprctl plugin load /tmp/hyprshell.so >/dev/null 2>&1; then
            log "Hyprshell plugin was missing and is now reloaded"
            exit 0
        fi
    fi
    log "Hyprshell plugin missing and reload failed; restarting hyprshell"
    systemctl --user restart hyprshell.service
    exit 0
fi

# Check if hyprshell socket exists
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    log "HYPRLAND_INSTANCE_SIGNATURE not set, skipping socket check"
    exit 0
fi

HYPR_RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}"
SOCKET_PATH="$HYPR_RUNTIME/hyprshell.sock"

if [[ ! -S "$SOCKET_PATH" ]]; then
    log "Hyprshell socket missing at $SOCKET_PATH after ${UPTIME}s uptime, restarting"
    systemctl --user restart hyprshell.service
    exit 0
fi

# Check for error loop - hyprshell stuck trying to get initial workspace
# This happens after monitor hotplug events
ERROR_COUNT=$(journalctl --user -u hyprshell.service --since "2 min ago" --no-pager 2>/dev/null | \
    grep -c "unable to get initial workspace" 2>/dev/null) || ERROR_COUNT=0

if [[ "$ERROR_COUNT" -gt 10 ]]; then
    log "Hyprshell stuck in error loop (${ERROR_COUNT} errors in last 2 min), restarting"
    systemctl --user restart hyprshell.service
    exit 0
fi

# All checks passed
exit 0

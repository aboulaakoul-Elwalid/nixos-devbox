#!/usr/bin/env bash

set -uo pipefail

PATH="$HOME/.local/bin:/run/current-system/sw/bin:$PATH"
LOG="/tmp/session-restore.log"
LOCK_FILE="/tmp/session-restore-v2.lock"
JQ_BIN="/run/current-system/sw/bin/jq"

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$1" >>"$LOG"
}

wait_for_hyprland() {
    for _ in {1..60}; do
        if hyprctl monitors >/dev/null 2>&1; then
            log "Hyprland ready"
            return 0
        fi
        sleep 0.5
    done

    log "ERROR: Hyprland not ready"
    return 1
}

has_window_match() {
    local jq_filter="$1"

    hyprctl clients -j 2>/dev/null | "$JQ_BIN" -e "$jq_filter" >/dev/null 2>&1
}

wait_for_window_match() {
    local jq_filter="$1"

    for _ in {1..40}; do
        if has_window_match "$jq_filter"; then
            return 0
        fi
        sleep 0.5
    done

    return 1
}

launch_if_missing() {
    local label="$1"
    local jq_filter="$2"
    shift 2

    if has_window_match "$jq_filter"; then
        log "$label already running"
        return 0
    fi

    log "Launching $label"
    "$@" >/dev/null 2>&1 9>&- &

    if wait_for_window_match "$jq_filter"; then
        log "$label window detected"
    else
        log "WARN: $label window was not detected before timeout"
    fi
}

main() {
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        : >"$LOG"
        log "Another restore is already running"
        exit 0
    fi

    : >"$LOG"
    log "Session restore starting"

    wait_for_hyprland || exit 1

    launch_if_missing "Brave" 'any(.[]; (.class // "") == "brave-browser" or (.initialClass // "") == "brave-browser")' uwsm-app -- brave
    launch_if_missing "Obsidian" 'any(.[]; ((.class // "") == "obsidian" or (.initialClass // "") == "obsidian" or (((.class // "") == "electron" or (.initialClass // "") == "electron") and ((((.title // "") | test(" - Obsidian")) or ((.initialTitle // "") | test(" - Obsidian")))))))' uwsm-app -- obsidian -disable-gpu --enable-wayland-ime
    launch_if_missing "Zed" 'any(.[]; (.class // "") == "dev.zed.Zed" or (.initialClass // "") == "dev.zed.Zed")' uwsm-app -- zed

    if ! /home/elwalid/.config/hypr/scripts/opencode-session-restore.sh >/dev/null 2>&1; then
        log "WARN: OpenCode session restore failed"
    fi

    exec 9>&-

    log "Done"
}

main "$@"

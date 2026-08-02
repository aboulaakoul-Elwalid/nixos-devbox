#!/usr/bin/env bash

# Exit immediately when any command fails
set -euo pipefail

log() {
    printf '%s hyprshell-prestart: %s\n' "$(date --iso-8601=seconds)" "$*" >&2
}

cleanup_runtime() {
    shopt -s nullglob
    local runtime_root="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr"
    for stale in "$runtime_root"/*/hyprshell.sock "$runtime_root"/*/hyprshell.lock; do
        [ -e "$stale" ] || continue
        rm -f "$stale" && log "Removed stale runtime file $stale"
    done
    shopt -u nullglob
}

cleanup_state() {
    local state_dir="$HOME/.local/share/hyprshell"

    if [ -f "$state_dir/lock" ]; then
        rm -f "$state_dir/lock"
        log "Removed lock file $state_dir/lock"
    fi
}

wait_for_ipc() {
    local attempt max_attempts
    max_attempts=120 # 60 seconds total

    for attempt in $(seq 1 "$max_attempts"); do
        if timeout 1 hyprctl activeworkspace &>/dev/null; then
            log "Hyprland IPC is responsive after $attempt attempts"
            return 0
        fi
        sleep 0.5
    done

    log "Hyprland IPC was not ready after $((max_attempts / 2)) seconds"
    return 1
}

wait_for_monitor() {
    local attempt max_attempts
    max_attempts=30 # 15 seconds total

    for attempt in $(seq 1 "$max_attempts"); do
        # Check if at least one monitor is detected and not disabled
        if hyprctl monitors -j 2>/dev/null | grep -q '"disabled": false'; then
            log "Active monitor detected after $attempt attempts"
            return 0
        fi
        sleep 0.5
    done

    log "No active monitor detected after $((max_attempts / 2)) seconds, proceeding anyway"
    return 0  # Don't fail, let hyprshell try anyway
}

# In manual keybind mode, make sure no stale hyprshell plugin stays loaded in Hyprland.
# A loaded plugin + manual binds can cause duplicate OpenSwitch events.
unload_plugin_if_loaded() {
    local plugin_path="/tmp/hyprshell.so"
    if hyprctl plugins list 2>/dev/null | grep -q 'hyprshell-hyprland-plugin'; then
        hyprctl plugin unload "$plugin_path" >/dev/null 2>&1 || true
        log "Requested unload of hyprshell plugin at $plugin_path"
    fi
}

cleanup_runtime
cleanup_state
wait_for_ipc
wait_for_monitor
unload_plugin_if_loaded

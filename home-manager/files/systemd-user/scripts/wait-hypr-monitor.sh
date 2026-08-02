#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s wait-hypr-monitor: %s\n' "$(date --iso-8601=seconds)" "$*" >&2
}

# Other tooling on this machine (nested/offscreen Hyprland test instances) can
# call `systemctl --user import-environment` and clobber the shared
# HYPRLAND_INSTANCE_SIGNATURE/WAYLAND_DISPLAY with a short-lived instance's
# values, which then go stale the moment that instance exits. Re-resolve the
# real, longest-running instance and stamp it back before any UI app starts,
# so a concurrent test session on another Hyprland-aware skill can't break
# waybar/hyprshell/swaybg for this session.
heal_hypr_env() {
  local instances oldest_line sig wl
  instances="$(timeout 1 /run/current-system/sw/bin/hyprctl instances -j 2>/dev/null)" || return 0
  [ -n "$instances" ] || return 0

  oldest_line="$(/run/current-system/sw/bin/jq -r '
    sort_by(.time) | .[0] | "\(.instance)\t\(.wl_socket)"
  ' <<<"$instances" 2>/dev/null)" || return 0
  [ -n "$oldest_line" ] && [ "$oldest_line" != "null	null" ] || return 0

  sig="${oldest_line%%$'\t'*}"
  wl="${oldest_line##*$'\t'}"
  [ -n "$sig" ] && [ -S "/run/user/$UID/hypr/$sig/.socket.sock" ] || return 0

  # Always stamp systemd's stored copy unconditionally: comparing against this
  # script's own inherited env is meaningless (it may already be correct while
  # systemd's separate stored copy is the stale one we're actually fixing).
  systemctl --user set-environment HYPRLAND_INSTANCE_SIGNATURE="$sig" WAYLAND_DISPLAY="$wl" 2>/dev/null || true
  export HYPRLAND_INSTANCE_SIGNATURE="$sig"
  export WAYLAND_DISPLAY="$wl"
  log "Re-synced HYPRLAND_INSTANCE_SIGNATURE/WAYLAND_DISPLAY to live instance $sig ($wl)"
}

heal_hypr_env

# Wait for hypr IPC and a non-Unknown active monitor before launching UI apps.
# Prevents early boot race where waybar binds to Unknown-1 (1024x768).
max_attempts=120
for attempt in $(seq 1 "$max_attempts"); do
  if ! timeout 1 /run/current-system/sw/bin/hyprctl monitors -j >/tmp/hypr-monitors.json 2>/dev/null; then
    sleep 0.5
    continue
  fi

  if /run/current-system/sw/bin/jq -e '
    map(select(.disabled == false))
    | any((.name != "Unknown-1") and (.width >= 1280) and (.height >= 720))
  ' /tmp/hypr-monitors.json >/dev/null 2>&1; then
    log "Ready monitor found after ${attempt} attempts"
    heal_hypr_env
    exit 0
  fi

  sleep 0.5
done

# Non-fatal timeout: let service continue to avoid deadlock.
heal_hypr_env
log "Timed out waiting for non-Unknown monitor; continuing"
exit 0

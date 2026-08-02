#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s hyprshell-poststart: %s\n' "$(date --iso-8601=seconds)" "$*" >&2
}

is_loaded() {
  hyprctl plugins list 2>/dev/null | grep -q 'hyprshell-hyprland-plugin'
}

if is_loaded; then
  log "Plugin already loaded"
  exit 0
fi

# Wait up to ~20s for hyprshell to finish plugin build.
for _ in $(seq 1 40); do
  if [ -f /tmp/hyprshell.so ]; then
    break
  fi
  sleep 0.5
done

if [ ! -f /tmp/hyprshell.so ]; then
  log "Plugin artifact /tmp/hyprshell.so not found, leaving fallback keybinds active"
  exit 0
fi

if hyprctl plugin load /tmp/hyprshell.so >/dev/null 2>&1; then
  log "Loaded hyprshell plugin /tmp/hyprshell.so"
else
  # Non-fatal: fallback keybinds in hypr_overrides.conf remain active.
  log "Plugin load failed, fallback keybinds remain active"
fi

exit 0

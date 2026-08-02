#!/usr/bin/env bash
# Why does capturing a nested session sometimes hang/fail?
# Tries the same capture under several conditions to find which actually works.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ACU="$(cd "$HERE/.." && pwd)/bin/acu-session"
export ACU_STATE_DIR="/tmp/acu-cap-$$"
S=""
cleanup() { [ -n "$S" ] && "$ACU" destroy "$S" >/dev/null 2>&1; rm -rf "$ACU_STATE_DIR"; }
trap cleanup EXIT

S="$("$ACU" start --name cap --size 800x600)" || exit 1
SIG="$("$ACU" info "$S" | sed -n 's/^signature=//p')"
DISP="$("$ACU" info "$S" | sed -n 's/^display=//p')"
echo "session=$S display=$DISP"

try() { # label
  local out="$ACU_STATE_DIR/$1.png"
  rm -f "$out"
  local t0 t1
  t0=$(date +%s%N 2>/dev/null || echo 0)
  if timeout 8 env WAYLAND_DISPLAY="$DISP" grim "$out" 2>"$ACU_STATE_DIR/$1.err"; then
    t1=$(date +%s%N 2>/dev/null || echo 0)
    printf '  OK      %-28s %s bytes (%sms)\n' "$1" "$(stat -c%s "$out" 2>/dev/null)" \
      "$(( (t1-t0)/1000000 ))"
  else
    printf '  FAIL    %-28s %s\n' "$1" "$(head -1 "$ACU_STATE_DIR/$1.err" 2>/dev/null)"
  fi
}

echo "=== capture conditions ==="
try "empty-immediately"

"$ACU" exec "$S" -- kitty >/dev/null 2>&1
sleep 5
try "just-after-window-open"

echo "  (idling 15s...)"; sleep 15
try "after-15s-idle"

WAYLAND_DISPLAY="$DISP" HYPRLAND_INSTANCE_SIGNATURE="$SIG" hyprctl dispatch forcerendererreload >/dev/null 2>&1
sleep 0.5
try "after-forcerendererreload"

HYPRLAND_INSTANCE_SIGNATURE="$SIG" hyprctl dispatch movecursor 400 300 >/dev/null 2>&1
sleep 0.5
try "after-movecursor"

WAYLAND_DISPLAY="$DISP" wtype "x" >/dev/null 2>&1
sleep 0.5
try "after-typing-into-window"

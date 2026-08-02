#!/usr/bin/env bash
# nested-sink.sh — reusable input-fidelity test rig.
#
# Spins up an isolated nested Hyprland and runs a terminal whose ONLY process is
# `cat > file` (no shell rc, no prompt, no completion, no vi-mode), so nothing
# but raw keyboard input can affect the captured bytes.
#
# SAFETY CONTRACT (learned the hard way, 2026-07-28):
#   This rig must NEVER launch a window onto the host desktop. Every launch is
#   gated on a positively-verified nested display that differs from the host's.
#   If that cannot be established, the rig ABORTS rather than falling back.
#
#   source nested-sink.sh
#   sink_start                # boot nested compositor (aborts if unverifiable)
#   sink_open <name>          # fresh cat-sink inside it; sets $SINK_FILE
#   ... type via WAYLAND_DISPLAY=$SINK_DISPLAY ...
#   sink_close                # EOF the sink, flush to disk
#   sink_stop                 # tear down, reaping orphans
set -uo pipefail

SINK_DIR="${SINK_DIR:-/tmp/hcu-sink-$$}"
SINK_DISPLAY=""
SINK_SIG=""
SINK_PID=""
SINK_FILE=""
SINK_HOST_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
SINK_TERM_PIDS=()

_sink_die() { echo "sink: FATAL: $*" >&2; return 1; }

# A nested Hyprland republishes its OWN WAYLAND_DISPLAY and
# HYPRLAND_INSTANCE_SIGNATURE into the shared systemd --user environment and
# never restores them. This rig spawns many short-lived compositors, so it was
# the biggest polluter on the machine: a concurrent agent counted 36+ instances
# in one day, and the stale values broke the user's waybar and swaybg.
#
# Anchor both to the LONGEST-RUNNING instance — the real desktop is always
# older than anything we spawn.
_sink_restore_env() {
  local rt="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" wl his
  wl="$SINK_HOST_DISPLAY"
  [ -S "$rt/$wl" ] || wl=""
  [ -n "$wl" ] && [ "$(systemctl --user show-environment 2>/dev/null | sed -n 's/^WAYLAND_DISPLAY=//p')" != "$wl" ] \
    && systemctl --user set-environment "WAYLAND_DISPLAY=$wl" 2>/dev/null
  his="$(hyprctl instances -j 2>/dev/null | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: raise SystemExit
if d: print(sorted(d, key=lambda i: i.get("time", 0))[0]["instance"])' 2>/dev/null)"
  [ -n "$his" ] && [ "$(systemctl --user show-environment 2>/dev/null | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p')" != "$his" ] \
    && systemctl --user set-environment "HYPRLAND_INSTANCE_SIGNATURE=$his" 2>/dev/null
  return 0
}

# Refuse to act unless we hold a verified nested target distinct from the host.
_sink_assert_nested() {
  [ -n "$SINK_DISPLAY" ] || { _sink_die "no nested display resolved"; return 1; }
  [ -n "$SINK_SIG" ]     || { _sink_die "no nested instance signature"; return 1; }
  [ -n "$SINK_PID" ]     || { _sink_die "no nested compositor pid"; return 1; }
  if [ "$SINK_DISPLAY" = "$SINK_HOST_DISPLAY" ]; then
    _sink_die "nested display '$SINK_DISPLAY' == host display — refusing to launch"
    return 1
  fi
  if ! kill -0 "$SINK_PID" 2>/dev/null; then
    _sink_die "nested compositor pid $SINK_PID is dead"
    return 1
  fi
  return 0
}

sink_start() {
  mkdir -p "$SINK_DIR"
  cat > "$SINK_DIR/bare.conf" <<'EOF'
monitor = , 1280x800@60, 0x0, 1
general { border_size = 1 gaps_in = 0 gaps_out = 0 }
decoration { blur { enabled = false } shadow { enabled = false } }
animations { enabled = false }
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    force_default_wallpaper = 0
}
EOF
  local before
  before=$(hyprctl instances -j | python3 -c \
    'import sys,json;print(" ".join(str(i["pid"]) for i in json.load(sys.stdin)))') || {
      _sink_die "cannot query host hyprctl"; return 1; }

  setsid env -u HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY="$SINK_HOST_DISPLAY" \
    Hyprland --config "$SINK_DIR/bare.conf" > "$SINK_DIR/nested.log" 2>&1 &

  local i info
  for i in $(seq 1 40); do
    sleep 0.5
    # Resolve pid/sig/display atomically from one JSON read, using the REAL key
    # names (wl_socket, not "wl socket" — that typo launched two terminals onto
    # the host desktop before this guard existed).
    info=$(hyprctl instances -j | python3 -c "
import sys, json
before = set('''$before'''.split())
new = [i for i in json.load(sys.stdin) if str(i['pid']) not in before]
if new:
    n = new[0]
    print('%s\t%s\t%s' % (n['pid'], n['instance'], n['wl_socket']))
" 2>/dev/null)
    if [ -n "$info" ]; then
      SINK_PID=$(printf '%s' "$info" | cut -f1)
      SINK_SIG=$(printf '%s' "$info" | cut -f2)
      SINK_DISPLAY=$(printf '%s' "$info" | cut -f3)
      break
    fi
  done

  _sink_assert_nested || { sink_stop; return 1; }
  _sink_restore_env
  echo "sink: nested up pid=$SINK_PID display=$SINK_DISPLAY (host=$SINK_HOST_DISPLAY)"
}

_sink_nclients() {
  HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" hyprctl clients -j 2>/dev/null \
    | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0
}

sink_open() {
  _sink_assert_nested || return 1
  local name="$1" i n
  SINK_FILE="$SINK_DIR/$name.txt"
  rm -f "$SINK_FILE"

  # Wait for the PREVIOUS sink terminal to fully disappear. Without this the old
  # (already EOF'd) window can still hold focus, so the next round's keystrokes
  # land in a dead terminal and the capture comes back empty — which reads as a
  # test failure but is really a focus race.
  for i in $(seq 1 25); do
    n=$(_sink_nclients); [ "${n:-0}" -eq 0 ] && break
    sleep 0.3
  done

  WAYLAND_DISPLAY="$SINK_DISPLAY" HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" setsid \
    kitty -e /bin/sh -c "exec cat > $SINK_FILE" >/dev/null 2>&1 &
  SINK_TERM_PIDS+=("$!")

  # Confirm the window materialised INSIDE the nested instance, not the host.
  local addr=""
  for i in $(seq 1 30); do
    sleep 0.4
    addr=$(HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" hyprctl clients -j 2>/dev/null | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: d = []
print(d[0]["address"] if len(d) == 1 else "")' 2>/dev/null)
    [ -n "$addr" ] && break
  done
  [ -z "$addr" ] && { _sink_die "terminal never appeared as sole nested window"; return 1; }

  # Focus deterministically instead of trusting spawn order.
  HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1
  sleep 1.0

  # Verify the sink process is actually reading before we type into it.
  for i in $(seq 1 20); do
    [ -e "$SINK_FILE" ] && break
    sleep 0.2
  done
  return 0
}

sink_close() {
  _sink_assert_nested || return 1
  sleep 0.5
  WAYLAND_DISPLAY="$SINK_DISPLAY" wtype -M ctrl -k d -m ctrl 2>/dev/null
  sleep 1.2
}

sink_stop() {
  local p
  for p in "${SINK_TERM_PIDS[@]:-}"; do
    [ -n "$p" ] && kill -9 "$p" 2>/dev/null
  done
  SINK_TERM_PIDS=()
  if [ -n "$SINK_PID" ]; then
    kill "$SINK_PID" 2>/dev/null
    sleep 1
    # SIGTERM removes the IPC socket but can leave the process alive, so
    # `hyprctl instances` looks clean while an orphan keeps running.
    kill -0 "$SINK_PID" 2>/dev/null && { kill -9 "$SINK_PID" 2>/dev/null; sleep 0.5; }
  fi
  [ -d "$SINK_DIR" ] && pkill -9 -f "Hyprland --config $SINK_DIR/bare.conf" 2>/dev/null
  pkill -9 -f "exec cat > $SINK_DIR" 2>/dev/null
  SINK_PID=""; SINK_SIG=""; SINK_DISPLAY=""
  _sink_restore_env
  echo "sink: torn down"
  return 0
}

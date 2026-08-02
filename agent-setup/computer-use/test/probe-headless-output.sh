#!/usr/bin/env bash
# Can an agent desktop render and be captured while the PHYSICAL monitor is
# off? That is the normal condition for remote/overnight work.
#
# ANSWER (2026-07-28): no. The headless output is created but stays 0x0, and
# assigning it a mode reports ok while changing nothing on Hyprland 0.54.3.
#
# Hypothesis (DISPROVED): a nested session's own headless output does not depend
# on the host presenting anything, so `hyprctl output create headless` inside the
# session should restore pixel capture even with the host at zero monitors.
#
# Runs entirely inside a nested session — the live desktop is never touched.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ACU="$(cd "$HERE/.." && pwd)/bin/acu-session"
export ACU_STATE_DIR="/tmp/acu-headless-$$"
S=""
cleanup() { [ -n "$S" ] && "$ACU" destroy "$S" >/dev/null 2>&1; rm -rf "$ACU_STATE_DIR"; }
trap cleanup EXIT

hostmon() { hyprctl monitors -j 2>/dev/null | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0; }
echo "host monitors: $(hostmon)  (0 == monitor off / disconnected)"

S="$("$ACU" start --name headless --size 1280x800)" || exit 1
SIG="$("$ACU" info "$S" | sed -n 's/^signature=//p')"
DISP="$("$ACU" info "$S" | sed -n 's/^display=//p')"
echo "session=$S display=$DISP"

sess() { HYPRLAND_INSTANCE_SIGNATURE="$SIG" hyprctl "$@" 2>/dev/null; }

echo
echo "=== session outputs BEFORE ==="
sess monitors -j | python3 -c '
import sys,json
d=json.load(sys.stdin); print("  count:",len(d))
for m in d: print("   ",m.get("name"),"%sx%s"%(m.get("width"),m.get("height")))'

cap() { # label
  local out="$ACU_STATE_DIR/$1.png"; rm -f "$out"
  if timeout 8 env WAYLAND_DISPLAY="$DISP" grim "$out" 2>"$ACU_STATE_DIR/$1.err"; then
    printf '  CAPTURE OK   %-22s %s bytes\n' "$1" "$(stat -c%s "$out" 2>/dev/null)"
  else
    printf '  CAPTURE FAIL %-22s %s\n' "$1" "$(head -1 "$ACU_STATE_DIR/$1.err" 2>/dev/null)"
  fi
}

echo "=== baseline capture (expected to fail with host output absent) ==="
cap baseline

echo
echo "=== create a headless output inside the session ==="
sess output create headless agentout | head -2
sleep 2
sess monitors -j | python3 -c '
import sys,json
d=json.load(sys.stdin); print("  count:",len(d))
for m in d: print("   ",m.get("name"),"%sx%s"%(m.get("width"),m.get("height")))'

echo "=== capture WITH headless output ==="
cap with-headless

echo
echo "=== launch an app onto it and capture again ==="
"$ACU" exec "$S" -- kitty >/dev/null 2>&1
sleep 5
echo "  windows: $("$ACU" windows "$S" | tail -1)"
cap with-window

echo
echo "=== grim per-output (target the headless one explicitly) ==="
OUTNAME=$(sess monitors -j | python3 -c '
import sys,json
d=json.load(sys.stdin)
print(d[-1]["name"] if d else "")')
echo "  targeting output: ${OUTNAME:-<none>}"
if [ -n "$OUTNAME" ]; then
  rm -f "$ACU_STATE_DIR/byout.png"
  if timeout 8 env WAYLAND_DISPLAY="$DISP" grim -o "$OUTNAME" "$ACU_STATE_DIR/byout.png" 2>"$ACU_STATE_DIR/byout.err"; then
    printf '  CAPTURE OK   %-22s %s bytes\n' "-o $OUTNAME" "$(stat -c%s "$ACU_STATE_DIR/byout.png")"
    cp "$ACU_STATE_DIR/byout.png" /tmp/headless-proof.png 2>/dev/null
    echo "  (copied to /tmp/headless-proof.png)"
  else
    printf '  CAPTURE FAIL %-22s %s\n' "-o $OUTNAME" "$(head -1 "$ACU_STATE_DIR/byout.err")"
  fi
fi

#!/usr/bin/env bash
# Session-manager gate. This is the P1 gate from research.md, made concrete:
#   "two agents work concurrently, zero focus/clipboard/window interference"
#
# Also covers the two failures found the hard way: displays that silently
# resolve to the host, and SIGTERM leaving orphaned compositors alive.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ACU="$(cd "$HERE/.." && pwd)/bin/acu-session"
export ACU_STATE_DIR="/tmp/acu-test-$$"

A=""; B=""
cleanup() {
  [ -n "$A" ] && "$ACU" destroy "$A" >/dev/null 2>&1
  [ -n "$B" ] && "$ACU" destroy "$B" >/dev/null 2>&1
  rm -rf "$ACU_STATE_DIR"
}
trap cleanup EXIT

PASS=0; FAIL=0
ok()   { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }
ck()   { if [ "$2" = "$3" ]; then ok "$1"; else printf '  FAIL  %s (want=%s got=%s)\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi; }

host_windows() { hyprctl clients -j | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))'; }
sess_windows() { "$ACU" windows "$1" 2>/dev/null | sed -n 's/^(\([0-9]*\) windows)$/\1/p'; }

HOST_BEFORE="$(host_windows)"
echo "=== acu-session gate (host starts with $HOST_BEFORE windows) ==="

A="$("$ACU" start --name testA --size 1024x768)" || { echo "start A failed"; exit 1; }
B="$("$ACU" start --name testB --size 1024x768)" || { echo "start B failed"; exit 1; }
ok "two concurrent sessions started ($A, $B)"

DA="$("$ACU" info "$A" | sed -n 's/^display=//p')"
DB="$("$ACU" info "$B" | sed -n 's/^display=//p')"
[ -n "$DA" ] && [ -n "$DB" ] && [ "$DA" != "$DB" ] \
  && ok "distinct displays ($DA vs $DB)" || bad "displays not distinct ($DA / $DB)"
[ "$DA" != "${WAYLAND_DISPLAY:-wayland-1}" ] && [ "$DB" != "${WAYLAND_DISPLAY:-wayland-1}" ] \
  && ok "neither session uses the host display" || bad "a session resolved to the host display"

# --- isolation ----------------------------------------------------------
"$ACU" exec "$A" -- kitty >/dev/null 2>&1
"$ACU" wait "$A" --for openwindow --timeout 25 --quiet || echo "  (warn: no openwindow event for A)"
ck "session A sees its 1 window"  "1" "$(sess_windows "$A")"
ck "session B still empty"        "0" "$(sess_windows "$B")"

"$ACU" exec "$B" -- kitty >/dev/null 2>&1
"$ACU" wait "$B" --for openwindow --timeout 25 --quiet || echo "  (warn: no openwindow event for B)"
ck "session B now has 1 window"   "1" "$(sess_windows "$B")"
ck "session A unchanged"          "1" "$(sess_windows "$A")"

# host gains only the two nested compositor surfaces, not the inner windows
HOST_NOW="$(host_windows)"
if [ "$HOST_NOW" -le $(( HOST_BEFORE + 2 )) ]; then
  ok "host window count contained ($HOST_BEFORE -> $HOST_NOW)"
else
  bad "host gained too many windows ($HOST_BEFORE -> $HOST_NOW) — leakage"
fi

# --- capture ------------------------------------------------------------
HOST_OUTPUTS="$(hyprctl monitors -j 2>/dev/null | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
if [ "${HOST_OUTPUTS:-0}" -eq 0 ]; then
  printf '  SKIP  %s\n' "capture (host monitor off — no output present; not a code fault)"
else
  IMG="$(timeout 40 "$ACU" capture "$A" "$ACU_STATE_DIR/a.png" 2>/dev/null || true)"
  if [ -n "$IMG" ] && [ -s "$IMG" ]; then
    ok "captured session A ($(stat -c%s "$IMG") bytes)"
  else
    bad "capture failed or timed out"
  fi
fi

# --- guard: acting on a dead session must abort -------------------------
DEADPID="$(python3 -c "import json;print(json.load(open('$ACU_STATE_DIR/$A/meta.json'))['pid'])")"
python3 - "$ACU_STATE_DIR/$A/meta.json" <<'EOF'
import json,sys
p=sys.argv[1]; m=json.load(open(p)); m['pid']=999999; json.dump(m,open(p,'w'))
EOF
if "$ACU" windows "$A" >/dev/null 2>&1; then
  bad "acted on a dead-pid session instead of aborting"
else
  ok "refuses to act on a dead session"
fi
python3 - "$ACU_STATE_DIR/$A/meta.json" "$DEADPID" <<'EOF'
import json,sys
p=sys.argv[1]; m=json.load(open(p)); m['pid']=int(sys.argv[2]); json.dump(m,open(p,'w'))
EOF

# --- guard: host-display session must abort -----------------------------
cp "$ACU_STATE_DIR/$A/meta.json" "$ACU_STATE_DIR/$A/meta.bak"
python3 - "$ACU_STATE_DIR/$A/meta.json" "${WAYLAND_DISPLAY:-wayland-1}" <<'EOF'
import json,sys
p=sys.argv[1]; m=json.load(open(p)); m['display']=sys.argv[2]; json.dump(m,open(p,'w'))
EOF
if "$ACU" windows "$A" >/dev/null 2>&1; then
  bad "acted on a session claiming the host display"
else
  ok "refuses a session whose display equals the host"
fi
mv "$ACU_STATE_DIR/$A/meta.bak" "$ACU_STATE_DIR/$A/meta.json"

# --- teardown + orphan reaping ------------------------------------------
PID_A="$(python3 -c "import json;print(json.load(open('$ACU_STATE_DIR/$A/meta.json'))['pid'])")"
"$ACU" destroy "$A" >/dev/null 2>&1
sleep 1
if kill -0 "$PID_A" 2>/dev/null; then
  bad "compositor $PID_A survived destroy (orphan)"
else
  ok "destroy reaped the compositor process"
fi
A=""

"$ACU" destroy "$B" >/dev/null 2>&1; B=""
sleep 1
LEFT="$(ps -eo args= | grep -F "Hyprland --config $ACU_STATE_DIR" | grep -vc grep || true)"
LEFT="${LEFT:-0}"
ck "no orphaned compositors remain" "0" "${LEFT:-0}"

HOST_AFTER="$(host_windows)"
ck "host window count restored" "$HOST_BEFORE" "$HOST_AFTER"

echo
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0

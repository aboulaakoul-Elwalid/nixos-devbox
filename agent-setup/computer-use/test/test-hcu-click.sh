#!/usr/bin/env bash
# Click-fidelity test for hcu-click.
#
# Oracle: a chromium page (own throwaway profile, --app so there is no browser
# chrome) writes every click's viewport coordinates into document.title. Window
# titles are readable through `hyprctl clients`, so we get an exact, textual
# answer to "did the click land, and where?" without CDP or screenshots.
#
# Runs only inside a nested Hyprland — never the live desktop.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export SINK_DIR="/tmp/hcu-click-$$"
# shellcheck source=/dev/null
source "$HERE/nested-sink.sh"

CHROME_PROFILE="$SINK_DIR/chrome-profile"
CHROME_PID=""
cleanup() {
  [ -n "$CHROME_PID" ] && kill -9 "$CHROME_PID" 2>/dev/null
  pkill -9 -f "user-data-dir=$CHROME_PROFILE" 2>/dev/null
  sink_stop
  rm -rf "$SINK_DIR"
}
trap cleanup EXIT

HCU_CLICK="${HCU_CLICK:-$HOME/.agents/skills/hyprland-computer-use/bin/hcu-click}"
[ -x "$HCU_CLICK" ] || { echo "no hcu-click at $HCU_CLICK" >&2; exit 1; }

sink_start || exit 1
mkdir -p "$CHROME_PROFILE"

cat > "$SINK_DIR/target.html" <<'EOF'
<!doctype html><meta charset="utf-8">
<style>
  html,body{margin:0;height:100%;background:#202430;color:#8fa;font:14px monospace}
  #g{display:grid;grid-template:repeat(3,1fr)/repeat(3,1fr);height:100%}
  div.c{border:1px solid #445;display:flex;align-items:center;justify-content:center}
</style>
<div id="g">
  <div class="c">1</div><div class="c">2</div><div class="c">3</div>
  <div class="c">4</div><div class="c">5</div><div class="c">6</div>
  <div class="c">7</div><div class="c">8</div><div class="c">9</div>
</div>
<script>
  let n = 0;
  document.title = "CLICKS:0";
  addEventListener('click', e => {
    n++;
    const cell = e.target.textContent.trim();
    document.title = `CLICKS:${n}|${e.clientX},${e.clientY}|cell${cell}`;
  });
  addEventListener('contextmenu', e => {
    e.preventDefault(); n++;
    document.title = `CLICKS:${n}|${e.clientX},${e.clientY}|RIGHT`;
  });
</script>
EOF

echo "=== launching chromium target in nested compositor ==="
WAYLAND_DISPLAY="$SINK_DISPLAY" HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" setsid \
  chromium --ozone-platform=wayland --disable-gpu --no-first-run \
    --no-default-browser-check --disable-features=Translate \
    --user-data-dir="$CHROME_PROFILE" \
    --app="file://$SINK_DIR/target.html" \
    --window-size=1000,700 >/dev/null 2>&1 &
CHROME_PID=$!

# wait for the window to exist inside the nested instance
WIN=""
for i in $(seq 1 60); do
  sleep 0.5
  WIN=$(HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" hyprctl clients -j 2>/dev/null | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: d = []
for c in d:
    if "CLICKS:" in c.get("title", ""):
        print("%s %s %s %s %s" % (c["address"], c["at"][0], c["at"][1], c["size"][0], c["size"][1]))
        break' 2>/dev/null)
  [ -n "$WIN" ] && break
done
[ -z "$WIN" ] && { echo "chromium target never appeared"; exit 1; }

read -r ADDR WX WY WW WH <<<"$WIN"
echo "target window: addr=$ADDR origin=($WX,$WY) size=${WW}x${WH}"
HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" hyprctl dispatch focuswindow "address:$ADDR" >/dev/null
sleep 1

title() {
  HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" hyprctl clients -j 2>/dev/null | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: d = []
for c in d:
    t = c.get("title", "")
    if "CLICKS:" in t: print(t); break'
}

PASS=0; FAIL=0
click_at() { # label, cell(1-9), button
  local label="$1" cell="$2" btn="${3:-left}"
  local col=$(( (cell-1) % 3 )) row=$(( (cell-1) / 3 ))
  # centre of that grid cell, in window-relative pixels
  local rx=$(( WW * (2*col+1) / 6 )) ry=$(( WH * (2*row+1) / 6 ))
  local ax=$(( WX + rx )) ay=$(( WY + ry ))
  local before after
  before="$(title)"
  WAYLAND_DISPLAY="$SINK_DISPLAY" HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" \
    "$HCU_CLICK" "$ax" "$ay" "$btn" >/dev/null 2>&1
  local rc=$?
  sleep 0.7
  after="$(title)"

  if [ "$before" = "$after" ]; then
    printf '  FAIL  %-22s exit=%s but title unchanged (%s) — click did NOT land\n' \
      "$label" "$rc" "$after"
    FAIL=$((FAIL+1)); return
  fi
  # got a click: check it hit the intended cell
  local gotcell
  gotcell=$(printf '%s' "$after" | sed -n 's/.*|cell\([0-9]\).*/\1/p')
  local gotxy
  gotxy=$(printf '%s' "$after" | sed -n 's/CLICKS:[0-9]*|\([0-9]*,[0-9]*\)|.*/\1/p')
  if [ "$btn" = "right" ]; then
    if printf '%s' "$after" | grep -q RIGHT; then
      printf '  PASS  %-22s right-click registered at %s\n' "$label" "$gotxy"; PASS=$((PASS+1))
    else
      printf '  FAIL  %-22s expected RIGHT, got %s\n' "$label" "$after"; FAIL=$((FAIL+1))
    fi
  elif [ "$gotcell" = "$cell" ]; then
    printf '  PASS  %-22s hit cell %s at %s (target %s,%s)\n' "$label" "$cell" "$gotxy" "$rx" "$ry"
    PASS=$((PASS+1))
  else
    printf '  FAIL  %-22s aimed cell %s, hit cell %s (at %s)\n' "$label" "$cell" "${gotcell:-?}" "$gotxy"
    FAIL=$((FAIL+1))
  fi
}

echo "=== click fidelity ==="
click_at "centre (cell5)"      5
click_at "top-left (cell1)"    1
click_at "bottom-right (cell9)" 9
click_at "top-right (cell3)"   3
click_at "bottom-left (cell7)" 7
click_at "right-click"         5 right

echo
echo "=== rapid repeat (does every click land?) ==="
b="$(title)"; n0=$(printf '%s' "$b" | sed -n 's/CLICKS:\([0-9]*\).*/\1/p')
for i in 1 2 3 4 5; do
  cx=$(( WX + WW/2 )); cy=$(( WY + WH/2 ))
  WAYLAND_DISPLAY="$SINK_DISPLAY" HYPRLAND_INSTANCE_SIGNATURE="$SINK_SIG" \
    "$HCU_CLICK" "$cx" "$cy" >/dev/null 2>&1
done
sleep 1
a="$(title)"; n1=$(printf '%s' "$a" | sed -n 's/CLICKS:\([0-9]*\).*/\1/p')
delivered=$(( n1 - n0 ))
if [ "$delivered" -eq 5 ]; then
  printf '  PASS  5 rapid clicks -> %s delivered\n' "$delivered"; PASS=$((PASS+1))
else
  printf '  FAIL  5 rapid clicks -> only %s delivered (dropped %s)\n' \
    "$delivered" $(( 5 - delivered )); FAIL=$((FAIL+1))
fi

echo
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0

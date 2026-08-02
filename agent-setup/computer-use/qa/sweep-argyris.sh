#!/usr/bin/env bash
# Sweep every primary control on the Argyris home screen and report which ones
# do something. One dead button is a bug; several is a pattern, and the two
# want different responses — hence a sweep rather than another single probe.
#
# Each control is exercised in a FRESH state (the UI is reloaded between
# clicks) so one control's side effects cannot mask or explain the next one's.
#
#   ./qa/sweep-argyris.sh [cdp-port]
set -uo pipefail
PORT="${1:-9334}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

command -v uv >/dev/null || { echo "needs uv"; exit 1; }
curl -sf --max-time 4 "http://127.0.0.1:$PORT/json/version" >/dev/null \
  || { echo "no CDP on $PORT — is the workbench running?"; exit 1; }

# Window count comes from the compositor, not the DOM: a control that opens a
# NATIVE dialog (file picker) changes nothing in the webview and would look
# dead otherwise.
win_count() {
  ACU_STATE_DIR=/tmp/acu-argyris-poc "$ROOT/bin/acu-session" windows argyris 2>/dev/null \
    | sed -n 's/^(\([0-9]*\) windows)$/\1/p'
}

CONTROLS=(
  "Build a review presentation"
  "Open a demo run"
  "Choose folder…"
  "Browse demo runs"
  "set your name"
)

printf '%-32s %-14s %-10s %s\n' "CONTROL" "UI TEXT" "WINDOWS" "VERDICT"
printf '%s\n' "------------------------------------------------------------------------"

for c in "${CONTROLS[@]}"; do
  w_before="$(win_count)"
  out="$(uv run --quiet --with websockets python "$ROOT/qa/bin/qa-vscode" \
          --port "$PORT" scenario --click "$c" --settle 5 2>&1)"
  w_after="$(win_count)"

  # "text 1147->1147"
  nums="$(printf '%s' "$out" | sed -n 's/.*text \([0-9]*\)->\([0-9]*\).*/\1 \2/p' | head -1)"
  b="${nums%% *}"; a="${nums##* }"
  moved="no"; [ -n "$b" ] && [ "$b" != "$a" ] && moved="yes"
  winmoved="no"; [ "${w_before:-0}" != "${w_after:-0}" ] && winmoved="yes"

  if printf '%s' "$out" | grep -q "NOT FOUND"; then
    verdict="CONTROL MISSING"
  elif [ "$moved" = "yes" ]; then
    verdict="responds (UI changed $b->$a)"
  elif [ "$winmoved" = "yes" ]; then
    verdict="responds (native window ${w_before}->${w_after})"
  else
    verdict="SILENT NO-OP"
  fi
  printf '%-32s %-14s %-10s %s\n' "$c" "${b:-?}->${a:-?}" "${w_before:-?}->${w_after:-?}" "$verdict"

  # return to a known state so the next control starts fresh
  uv run --quiet --with websockets python - "$PORT" <<'PY' >/dev/null 2>&1 || true
import json,sys,urllib.request
import websockets.sync.client as wsc
p=sys.argv[1]
t=[x for x in json.load(urllib.request.urlopen(f"http://127.0.0.1:{p}/json/list",timeout=8))
   if x.get("type")=="iframe" and "webview" in x.get("url","")]
if t:
    with wsc.connect(t[0]["webSocketDebuggerUrl"],max_size=20_000_000) as ws:
        ws.send(json.dumps({"id":1,"method":"Page.reload"}))
        ws.recv()
PY
  sleep 6
done

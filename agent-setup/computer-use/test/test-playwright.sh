#!/usr/bin/env bash
# Proves playwright-cli works end-to-end on this machine as a DETERMINISTIC
# verifier: load a page, read state, act on a semantic element ref, observe the
# state actually changed, and capture console errors.
#
# Headless throughout — nothing appears on the desktop.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PWCLI="${PWCLI:-$HOME/.codex/skills/playwright/scripts/playwright_cli.sh}"
[ -x "$PWCLI" ] || { echo "playwright wrapper not found at $PWCLI" >&2; exit 1; }

WS="$(mktemp -d /tmp/pw-verify-XXXXXX)"
PORT="${PORT:-8901}"
SESSION="verify-$$"
SRV_PID=""

cleanup() {
  "$PWCLI" -s="$SESSION" close >/dev/null 2>&1
  [ -n "$SRV_PID" ] && kill -9 "$SRV_PID" 2>/dev/null
  rm -rf "$WS"
}
trap cleanup EXIT

PASS=0; FAIL=0
ck() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; PASS=$((PASS+1));
       else printf '  FAIL  %s\n        want=%s\n        got =%s\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi; }

mkdir -p "$WS/site"
cat > "$WS/site/page.html" <<'EOF'
<!doctype html><title>PW Verify</title>
<h1 id="h">initial</h1>
<button id="b" onclick="document.getElementById('h').textContent='changed'">Go</button>
<script>fetch('/definitely-missing').catch(()=>{});</script>
EOF

( cd "$WS/site" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 ) &
SRV_PID=$!
for i in $(seq 1 30); do
  curl -sf -o /dev/null "http://127.0.0.1:$PORT/page.html" && break
  sleep 0.3
done

"$ROOT/bin/pw-init" "$WS" >/dev/null || { echo "pw-init failed"; exit 1; }
cd "$WS"

echo "=== playwright deterministic-verifier check ==="
"$PWCLI" -s="$SESSION" open "http://127.0.0.1:$PORT/page.html" >/dev/null 2>&1

title=$("$PWCLI" -s="$SESSION" --raw eval "() => document.title" 2>/dev/null | tr -d '"')
ck "page loads"            "PW Verify" "$title"

before=$("$PWCLI" -s="$SESSION" --raw eval "() => document.getElementById('h').textContent" 2>/dev/null | tr -d '"')
ck "state before action"   "initial" "$before"

# act on a SEMANTIC ref from the accessibility snapshot, not a pixel
ref=$("$PWCLI" -s="$SESSION" snapshot 2>/dev/null | sed -n 's/.*button "Go" \[ref=\([a-z0-9]*\)\].*/\1/p' | head -1)
[ -n "$ref" ] && { printf '  PASS  %s\n' "snapshot yields element ref ($ref)"; PASS=$((PASS+1)); } \
              || { printf '  FAIL  %s\n' "snapshot yielded no element ref"; FAIL=$((FAIL+1)); }
"$PWCLI" -s="$SESSION" click "${ref:-e3}" >/dev/null 2>&1

after=$("$PWCLI" -s="$SESSION" --raw eval "() => document.getElementById('h').textContent" 2>/dev/null | tr -d '"')
ck "state changed by click" "changed" "$after"

# the network/console channel is the point of using playwright over pixels
errs=$("$PWCLI" -s="$SESSION" console 2>/dev/null | grep -c 'definitely-missing' || true)
if [ "${errs:-0}" -ge 1 ]; then
  printf '  PASS  %s\n' "console captures failed request"; PASS=$((PASS+1))
else
  printf '  FAIL  %s\n' "console did not capture the failed request"; FAIL=$((FAIL+1))
fi

echo
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0

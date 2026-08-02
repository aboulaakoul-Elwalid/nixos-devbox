#!/usr/bin/env bash
# Oracle discrimination gate.
#
# A QA harness is only worth running if it BOTH finds real bugs and stays quiet
# on healthy paths. Testing only the broken case tells you nothing — a harness
# that flags everything would pass that test. So this runs a 3x2 matrix and
# requires the right answer in every cell.
#
#   build          scenario      expected
#   -----------------------------------------
#   buggy:500      apostrophe    BUG
#   buggy:500      plain         clean
#   buggy:silent   apostrophe    BUG   (via state-divergence ONLY)
#   buggy:silent   plain         clean
#   fixed          apostrophe    clean
#   fixed          plain         clean
#
# The silent-drop row is the important one: HTTP 201, no console error, page
# renders "Saved!". If state-divergence ever regresses, that row goes green-
# looking-but-wrong, so the gate asserts the SIGNAL, not just the verdict.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WS="$(mktemp -d /tmp/qa-gate-XXXXXX)"
PIDS=()

cleanup() {
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill -9 "$p" 2>/dev/null; done
  rm -rf "$WS"
}
trap cleanup EXIT

start_fixture() { # port, extra-flag
  python3 "$HERE/fixture/notes_app.py" --port "$1" ${2:-} >"$WS/fx-$1.log" 2>&1 &
  PIDS+=("$!")
  for _ in $(seq 1 40); do
    curl -sf -o /dev/null "http://127.0.0.1:$1/api/health" && return 0
    sleep 0.25
  done
  echo "fixture on $1 failed to start"; return 1
}

PASS=0; FAIL=0
ck() { # label, expected(BUG|clean), url, scenario, [required-signal]
  local label="$1" expect="$2" url="$3" scen="$4" need="${5:-}"
  local out="$WS/$label"
  QA_WORKSPACE="$WS" "$ROOT/qa/bin/qa-run" --url "$url" --scenario "$scen" --out "$out" >/dev/null 2>&1
  local got
  got=$(python3 -c "
import json,sys
try: t=json.load(open('$out/trace.json'))
except Exception: print('ERROR'); sys.exit()
print('BUG' if t['verdict']['bug'] else 'clean')")
  if [ "$got" != "$expect" ]; then
    printf '  FAIL  %-26s expected %-5s got %s\n' "$label" "$expect" "$got"
    FAIL=$((FAIL+1)); return
  fi
  if [ -n "$need" ]; then
    local sigs
    sigs=$(python3 -c "
import json
t=json.load(open('$out/trace.json'))
print(','.join(f['signal'] for f in t['verdict']['findings']))")
    if [[ ",$sigs," != *",$need,"* ]]; then
      printf '  FAIL  %-26s expected signal %s, got [%s]\n' "$label" "$need" "$sigs"
      FAIL=$((FAIL+1)); return
    fi
    printf '  PASS  %-26s %s (via %s)\n' "$label" "$expect" "$need"
  else
    printf '  PASS  %-26s %s\n' "$label" "$expect"
  fi
  PASS=$((PASS+1))
}

command -v curl >/dev/null || { echo "curl required"; exit 1; }
"$ROOT/bin/pw-init" "$WS" >/dev/null || { echo "pw-init failed"; exit 1; }

# fresh fixtures so note counts start from a known state
start_fixture 8920           || exit 1   # buggy: 500
start_fixture 8921 --fixed   || exit 1   # fixed
start_fixture 8922 --silent-drop || exit 1  # buggy: silent drop

echo "=== oracle discrimination matrix ==="
ck "buggy500-apostrophe"  BUG   http://127.0.0.1:8920 save-apostrophe server-error
ck "buggy500-plain"       clean http://127.0.0.1:8920 save-plain
ck "silentdrop-apostrophe" BUG  http://127.0.0.1:8922 save-apostrophe state-divergence
ck "silentdrop-plain"     clean http://127.0.0.1:8922 save-plain
ck "fixed-apostrophe"     clean http://127.0.0.1:8921 save-apostrophe
ck "fixed-plain"          clean http://127.0.0.1:8921 save-plain

echo
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0

#!/usr/bin/env bash
# Fail-before / pass-after gate.
#
# A finding is only evidence if it can be replayed. This gate proves the repro
# discriminates between builds: the SAME repro must reproduce on the build the
# bug was found on, and must NOT reproduce on the repaired build.
#
# Both directions are required. A repro that always fires proves nothing (it
# would "reproduce" on a healthy build too); a repro that never fires is dead
# weight that silently green-lights regressions.
#
# Covers both planted bugs, including the silent-drop one whose only signal is
# state divergence.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WS="$(mktemp -d /tmp/qa-repro-XXXXXX)"
PIDS=()
cleanup() {
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill -9 "$p" 2>/dev/null; done
  rm -rf "$WS"
}
trap cleanup EXIT

start_fixture() {
  python3 "$HERE/fixture/notes_app.py" --port "$1" ${2:-} >"$WS/fx-$1.log" 2>&1 &
  PIDS+=("$!")
  for _ in $(seq 1 40); do
    curl -sf -o /dev/null "http://127.0.0.1:$1/api/health" && return 0
    sleep 0.25
  done
  echo "fixture $1 failed to start"; return 1
}

PASS=0; FAIL=0
ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }

"$ROOT/bin/pw-init" "$WS" >/dev/null || { echo "pw-init failed"; exit 1; }
start_fixture 8930                || exit 1   # buggy: 500
start_fixture 8931 --fixed        || exit 1   # fixed
start_fixture 8932 --silent-drop  || exit 1   # buggy: silent drop

# case: label, buggy-url, expected-signal, [--prefer SIGNAL]
run_case() {
  local label="$1" buggy_url="$2" want_signal="$3"; shift 3
  local run="$WS/run-$label" repro="$WS/repro-$label"

  QA_WORKSPACE="$WS" "$ROOT/qa/bin/qa-run" \
    --url "$buggy_url" --scenario save-apostrophe --out "$run" >/dev/null 2>&1

  if ! QA_WORKSPACE="$WS" "$ROOT/qa/bin/qa-compile" \
        --trace "$run/trace.json" --out "$repro" "$@" >"$WS/compile-$label.log" 2>&1; then
    bad "$label: compile produced no repro"; return
  fi
  local got_signal
  got_signal=$(python3 -c "import json;print(json.load(open('$repro/repro.json'))['reproduces'])")
  if [ "$got_signal" != "$want_signal" ]; then
    bad "$label: repro targets $got_signal, expected $want_signal"; return
  fi
  ok "$label: compiled repro targeting $got_signal"

  # fail-before: must reproduce on the build it was found on
  if QA_WORKSPACE="$WS" "$ROOT/qa/bin/qa-verify" \
       --repro "$repro/repro.json" --url "$buggy_url" >"$WS/before-$label.log" 2>&1; then
    ok "$label: REPRODUCED on buggy build (fail-before)"
  else
    bad "$label: did NOT reproduce on the buggy build — repro is dead weight"
    sed 's/^/        /' "$WS/before-$label.log"
  fi

  # pass-after: must NOT reproduce on the repaired build
  if QA_WORKSPACE="$WS" "$ROOT/qa/bin/qa-verify" \
       --repro "$repro/repro.json" --url http://127.0.0.1:8931 >"$WS/after-$label.log" 2>&1; then
    bad "$label: STILL reproduces on the fixed build — repro fires regardless (useless)"
    sed 's/^/        /' "$WS/after-$label.log"
  else
    ok "$label: not reproduced on fixed build (pass-after)"
  fi
}

echo "=== fail-before / pass-after ==="
# default selection: on the 500 build BOTH signals fire, and the compiler must
# pick the user-facing harm (state-divergence), not the mechanism (the 500).
run_case "err500-default"  http://127.0.0.1:8930 state-divergence
# --prefer pins the mechanism instead, which also exercises the OTHER assertion
# path (server_error_observed) — otherwise it would never be tested.
run_case "err500-pinned"   http://127.0.0.1:8930 server-error --prefer server-error
# silent-drop has only one available signal.
run_case "silentdrop"      http://127.0.0.1:8932 state-divergence

echo
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0

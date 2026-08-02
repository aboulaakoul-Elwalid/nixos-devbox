#!/usr/bin/env bash
# Gate for the `hassoub` skill's front door.
#
# The front door is a dispatcher, so this does NOT re-test the oracle (that has
# its own 3x2 gate). It tests the things a dispatcher can get wrong and that no
# other gate covers:
#
#   * does the verdict/exit code match reality on known-good and known-bad builds
#   * is --json a single parseable object (a stray print breaks every caller)
#   * does it stay QUIET on a healthy app (a harness that cries wolf is ignored)
#   * does it refuse, rather than guess, when it cannot establish a target
#   * does it clean up after itself
#
# The last one is here because it already failed once: `local` variables are out
# of scope when an EXIT trap fires, so the editor lane leaked a compositor, 12
# codium processes and its session directory while appearing to have cleanup.
#
#   ./test/test-verify-skill.sh            # skips the slow editor lane
#   VERIFY_TEST_EDITOR=1 ./test/...        # include it (needs a live display)
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
V="${VERIFY_BIN:-$HOME/.agents/skills/hassoub/bin/verify}"
PASS=0; FAIL=0
BASE_PORT=${BASE_PORT:-8980}

ok()   { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; FAIL=$((FAIL+1)); }

[ -x "$V" ] || { echo "verify not installed at $V — run ./install.sh deploy"; exit 2; }

fixture() { # flags, port -> prints pid
  python3 "$HERE/qa/fixture/notes_app.py" --port "$2" $1 >/dev/null 2>&1 &
  echo $!
}

echo "=== preconditions ==="
if "$V" doctor >/dev/null 2>&1; then ok "doctor reports ready"
else bad "doctor reports ready" "run '$V doctor' to see what is missing"; echo; echo "cannot continue"; exit 1; fi

echo "=== verdicts track reality (fail-before / pass-after) ==="
# Results go to a FILE and the caller runs in this shell, never in $( ).
# Command substitution forks a subshell, so an earlier version lost both the
# PASS/FAIL lines and the counter increments from these three cases — the gate
# printed "passed: 9" while silently having run 12 checks. A gate that
# under-reports its own coverage is the same failure class it exists to catch.
RUN_OUT=""
run_app() { # flags, port, expect-exit, label
  local pid rc
  pid="$(fixture "$1" "$2")"; sleep 2
  RUN_OUT="$(mktemp)"
  timeout 200 "$V" app "http://127.0.0.1:$2" --scenario save-apostrophe >"$RUN_OUT" 2>&1
  rc=$?
  kill "$pid" 2>/dev/null; sleep 0.5
  if [ "$rc" = "$3" ]; then ok "$4 (exit $rc)"
  else bad "$4" "expected exit $3, got $rc: $(head -1 "$RUN_OUT")"; fi
}
run_app ""              "$((BASE_PORT+1))" 1 "buggy-500 -> findings";   out500="$RUN_OUT"
run_app "--silent-drop" "$((BASE_PORT+2))" 1 "silent-drop -> findings"; outdrop="$RUN_OUT"
run_app "--fixed"       "$((BASE_PORT+3))" 0 "fixed -> healthy";        outfix="$RUN_OUT"

# The silent-drop build returns HTTP 201 and renders "Saved!" while storing
# nothing, so ONLY state-divergence can catch it. If this row ever passes via
# server-error instead, the strongest signal has quietly stopped working.
if grep -q "state-divergence" "$outdrop"; then ok "silent-drop caught by state-divergence"
else bad "silent-drop caught by state-divergence" "$(head -2 "$outdrop")"; fi
if grep -q "VERDICT: ok" "$outfix"; then ok "healthy build reports no findings"
else bad "healthy build reports no findings" "$(head -2 "$outfix")"; fi
# The 500 build must fire server-error; if it ever passes on state-divergence
# alone, the cheap high-precision signal has stopped working.
if grep -q "server-error" "$out500"; then ok "buggy-500 caught by server-error"
else bad "buggy-500 caught by server-error" "$(head -2 "$out500")"; fi
rm -f "$out500" "$outdrop" "$outfix"

echo "=== --json is a single parseable object ==="
pid="$(fixture "" "$((BASE_PORT+4))")"; sleep 2
j="$(timeout 200 "$V" app "http://127.0.0.1:$((BASE_PORT+4))" --json 2>/dev/null)"
kill "$pid" 2>/dev/null
if printf '%s' "$j" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['verdict'] in ('ok', 'findings'), d
assert isinstance(d['findings'], int)
assert isinstance(d['detail'], list)
" 2>/dev/null; then ok "json parses with the documented shape"
else bad "json parses with the documented shape" "$(printf '%s' "$j" | head -c 160)"; fi

echo "=== quiet on a healthy app (no false alarm) ==="
pid="$(fixture "--fixed" "$((BASE_PORT+5))")"; sleep 2
wout="$(timeout 240 "$V" web "http://127.0.0.1:$((BASE_PORT+5))" 4 2>&1)"; wrc=$?
kill "$pid" 2>/dev/null
if [ "$wrc" = "0" ]; then ok "web sweep silent on known-good build"
else bad "web sweep silent on known-good build" "$(printf '%s' "$wout" | head -2)"; fi
# The sweep is weak by construction; the verdict must SAY so, or an "ok" here
# reads as "the app works" when the sweep never entered any data.
if printf '%s' "$wout" | grep -q "scope:"; then ok "web verdict states its scope"
else bad "web verdict states its scope" "no scope line in output"; fi

echo "=== refuses instead of guessing ==="
if "$V" dialog find >/dev/null 2>&1; then bad "dialog refuses with no chooser open" "it returned success"
else ok "dialog refuses with no chooser open"; fi
if "$V" editor /tmp >/dev/null 2>&1; then bad "editor rejects a non-extension dir" "it accepted /tmp"
else ok "editor rejects a non-extension dir"; fi
if COMPUTER_USE_REPO=/nonexistent "$V" doctor >/dev/null 2>&1; then
  bad "blocks on a missing toolchain repo" "it ran anyway"
else ok "blocks on a missing toolchain repo"; fi

echo "=== a bare target routes itself (the 'just test this' path) ==="
pid="$(fixture "" "$((BASE_PORT+6))")"; sleep 2
rout="$(timeout 200 "$V" "http://127.0.0.1:$((BASE_PORT+6))" 2>&1)"; rrc=$?
kill "$pid" 2>/dev/null
if [ "$rrc" = "1" ] && printf '%s' "$rout" | grep -q "VERDICT: findings"; then
  ok "bare URL routes to the oracle lane and finds the bug"
else bad "bare URL routes to the oracle lane and finds the bug" "exit $rrc: $(printf '%s' "$rout" | head -1)"; fi
# Routing chatter must go to stderr, or --json stops being one parseable object.
jrout="$(timeout 200 "$V" "http://127.0.0.1:$((BASE_PORT+6))" --json 2>/dev/null)"
if [ -z "$jrout" ] || printf '%s' "$jrout" | python3 -c "import sys,json;json.load(sys.stdin)" 2>/dev/null; then
  ok "routing note does not pollute --json"
else bad "routing note does not pollute --json" "$(printf '%s' "$jrout" | head -c 120)"; fi
# Refusing beats guessing: a wrong guess would run a WEAKER check than asked for.
uout="$("$V" ./definitely-not-a-target 2>&1)"
if printf '%s' "$uout" | grep -q "don't know how to test"; then ok "unroutable target is refused with guidance"
else bad "unroutable target is refused with guidance" "$(printf '%s' "$uout" | head -1)"; fi
dout2="$("$V" /tmp 2>&1)"
if printf '%s' "$dout2" | grep -q "no package.json"; then ok "directory without package.json is refused"
else bad "directory without package.json is refused" "$(printf '%s' "$dout2" | head -1)"; fi

echo "=== dependencies are proven to RUN, not merely to exist ==="
# doctor once said "hcu-dialog: ok" because the file existed, while its only way
# to act (hcu-click, which ships in a SIBLING skill and is not on PATH) was
# unreachable — so the first real gesture died halfway and left a live dialog
# half-driven. The check must execute the thing.
# NOTE: capture, then grep. Under `set -o pipefail` a pipeline reports the
# LEFT side's status, and the commands below exit non-zero precisely BECAUSE
# refusing is the behaviour under test — piping into grep marked all of that
# correct behaviour as failure. (`grep -q` also SIGPIPEs the writer.) The gate
# was reporting red for working code, the mirror of the green-that-measures-
# nothing bug it exists to catch.
dout="$("$V" doctor 2>&1)"
if printf '%s' "$dout" | grep -qE "hcu-dialog +ok \(runs"; then ok "doctor executes hcu-dialog"
else bad "doctor executes hcu-dialog" "$(printf '%s' "$dout" | grep hcu-dialog || echo 'no hcu-dialog line')"; fi

# ...and with that dependency genuinely unreachable it must refuse up front,
# before touching anything, rather than failing mid-gesture.
nout="$(env -i PATH=/run/current-system/sw/bin:/usr/bin:/bin HOME=/nonexistent \
        bash "$HERE/bin/hcu-dialog" find 2>&1)"
if printf '%s' "$nout" | grep -q "refusing to act"; then
  ok "hcu-dialog refuses up front when hcu-click is unreachable"
else bad "hcu-dialog refuses up front when hcu-click is unreachable" "$(printf '%s' "$nout" | head -1)"; fi

echo "=== interaction verbs (the multi-step half) ==="
"$V" stop >/dev/null 2>&1
for verb in "observe" "click x" "key Enter" "type hi"; do
  if "$V" $verb >/dev/null 2>&1; then bad "'$verb' refuses with no editor running" "it returned success"
  else ok "'$verb' refuses with no editor running"; fi
done
sout="$("$V" stop 2>&1)"
if printf '%s' "$sout" | grep -q "nothing running"; then ok "stop is safe when nothing is running"
else bad "stop is safe when nothing is running" "$(printf '%s' "$sout" | head -1)"; fi
# A chord is what reaches the Command Palette; a bare key set could not.
kout="$(uv run --with websockets "$HERE/qa/bin/qa-vscode" --port 9 key "hyper+p" 2>&1)"
if printf '%s' "$kout" | grep -q "unknown modifier"; then ok "key rejects an unknown modifier"
else bad "key rejects an unknown modifier" "$(printf '%s' "$kout" | head -1)"; fi

echo "=== leaves no mess ==="
if [ "${VERIFY_TEST_EDITOR:-0}" = "1" ]; then
  ext="${VERIFY_TEST_EXT:-/home/elwalid/projects/cae-assistant-spike-kilo/clients/vscode-extension}"
  if [ -f "$ext/package.json" ]; then
    export ACU_STATE_DIR="${ACU_STATE_DIR:-$HOME/.local/share/acu/sessions}"
    # `pgrep -c` prints 0 AND exits 1 when nothing matches, so `|| echo 0`
    # appends a SECOND zero and the variable becomes multi-line garbage.
    n_codium() { local n; n="$(pgrep -c codium 2>/dev/null || true)"; echo "${n:-0}"; }
    n_inst()   { hyprctl instances -j | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))'; }

    # Start from a known baseline instead of trusting whatever is already
    # running: an earlier run's editor made "before" nonzero and turned a clean
    # teardown into a phantom failure.
    "$V" stop >/dev/null 2>&1
    for _ in $(seq 1 20); do [ "$(n_codium)" = "0" ] && break; sleep 1; done
    b_i=$(n_inst); b_c=$(n_codium)

    timeout 300 "$V" editor "$ext" --keep >/dev/null 2>&1
    if "$V" observe >/dev/null 2>&1; then ok "--keep leaves the editor reachable"
    else bad "--keep leaves the editor reachable"; fi
    if "$V" editor "$ext" --keep >/dev/null 2>&1; then
      bad "refuses to start a second editor over a live one"
    else ok "refuses to start a second editor over a live one"; fi

    # POLL for teardown rather than sleeping a guessed interval. Measured: an
    # editor takes ~2s to fully exit, and a fixed `sleep 3` raced it.
    "$V" stop >/dev/null 2>&1
    for _ in $(seq 1 25); do
      [ "$(n_codium)" = "$b_c" ] && [ "$(n_inst)" = "$b_i" ] && break
      sleep 1
    done
    a_i=$(n_inst); a_c=$(n_codium)
    a_p=$(ls -d /tmp/verify-editor-* 2>/dev/null | wc -l | tr -d ' ')
    if [ "$b_i" = "$a_i" ] && [ "$b_c" = "$a_c" ] && [ "$a_p" = "0" ]; then
      ok "editor lane leaves no compositor/process/profile behind"
    else
      bad "editor lane leaves no compositor/process/profile behind" \
          "instances $b_i->$a_i, codium $b_c->$a_c, profiles $a_p"
    fi
  else
    echo "  SKIP  editor leak check (no extension at $ext)"
  fi
else
  echo "  SKIP  editor leak check (set VERIFY_TEST_EDITOR=1)"
fi

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]

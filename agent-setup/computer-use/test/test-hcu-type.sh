#!/usr/bin/env bash
# Regression test for hcu-type input fidelity.
#
# Runs inside an isolated nested Hyprland, typing into a terminal whose only
# process is `cat > file` — so the bytes compared are exactly the bytes the
# virtual keyboard delivered, with no shell, prompt, completion or vi-mode in
# the way.
#
# One sink terminal is opened for the WHOLE run and trials are separated by a
# Return (a single-key press, which is never affected by the keymap-overflow
# bug). Respawning a terminal per trial raced against window focus and produced
# phantom "empty capture" failures.
#
#   ./test-hcu-type.sh
#   HCU=/path/to/hcu-type ./test-hcu-type.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export SINK_DIR="/tmp/hcu-test-$$"
# shellcheck source=/dev/null
source "$HERE/nested-sink.sh"
trap 'sink_stop; rm -rf "$SINK_DIR"' EXIT

HCU="${HCU:-$HOME/.agents/skills/hyprland-computer-use/bin/hcu-type}"
[ -x "$HCU" ] || { echo "no hcu-type at $HCU" >&2; exit 1; }

NAMES=(); EXPECTED=()
trial() { # name, expected, cmd...
  local name="$1" want="$2"; shift 2
  NAMES+=("$name"); EXPECTED+=("$want")
  WAYLAND_DISPLAY="$SINK_DISPLAY" "$@" >/dev/null 2>&1
  sleep 0.25
  WAYLAND_DISPLAY="$SINK_DISPLAY" wtype -k Return
  sleep 0.25
}

sink_start || exit 1
sink_open run  || exit 1
echo "=== hcu-type regression ($HCU) ==="

ALNUM="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
LONGREP="$(printf 'ab%.0s' {1..40})"
PUNCT='a!@#$%^&*()_+{}|:"<>?'
CMD='git commit -m "fix: keymap overflow (N/O to Tab)"'

# Control: raw wtype on 36 distinct chars — documents the bug still exists.
trial "raw-wtype-baseline"  "$ALNUM"          wtype "$ALNUM"
# The fix, across the cases that matter.
trial "alnum-36"             "$ALNUM"          "$HCU" "$ALNUM"
trial "upper-13"             "ABCDEFGHIJKLM"   "$HCU" "ABCDEFGHIJKLM"
trial "upper-14"             "ABCDEFGHIJKLMN"  "$HCU" "ABCDEFGHIJKLMN"
trial "realistic-cmdline"   "$CMD"            "$HCU" "$CMD"
trial "leading-dash"        "--flag=value"    "$HCU" "--flag=value"
trial "dash-only"          "---"             "$HCU" "---"
trial "dash-heavy"         "-a -b --c=d"     "$HCU" "-a -b --c=d"
trial "upper-26"           "ABCDEFGHIJKLMNOPQRSTUVWXYZ" "$HCU" "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
trial "punct-heavy"        "$PUNCT"          "$HCU" "$PUNCT"
trial "unicode"             "café naïve"      "$HCU" "café naïve"
trial "80char-2distinct"    "$LONGREP"        "$HCU" "$LONGREP"
trial "key-passthrough"     "x"               "$HCU" -k x


sink_close
mapfile -t GOT < <(cat "$SINK_FILE" 2>/dev/null)

PASS=0; FAIL=0; FAILED=()
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"; want="${EXPECTED[$i]}"; got="${GOT[$i]-<missing>}"
  if [ "$want" = "$got" ]; then
    printf '  PASS  %s\n' "$name"; PASS=$((PASS+1))
  else
    printf '  FAIL  %s\n        want=%q\n        got =%q\n' "$name" "$want" "$got"
    FAIL=$((FAIL+1)); FAILED+=("$name")
  fi
done

# Alignment guard: a stray newline from hcu-type would shift every later line.
if [ "${#GOT[@]}" -ne "${#NAMES[@]}" ]; then
  printf '  WARN  line-count mismatch: got %d lines for %d trials (stray newline?)\n' \
    "${#GOT[@]}" "${#NAMES[@]}"
fi

echo
echo "=== $PASS passed, $FAIL failed ==="
# NOTE: --strategy paste is deliberately NOT gated here. It depends on the
# TARGET APPLICATION's paste keybinding, and a terminal may forward Ctrl+Shift+V
# as an escape sequence (\E[118;6u) instead of pasting — making the result
# non-deterministic in this harness rather than a property of hcu-type.
#
# raw-wtype-baseline is EXPECTED to fail while the upstream bug exists.
if [ "$FAIL" -eq 1 ] && [ "${FAILED[0]}" = "raw-wtype-baseline" ]; then
  echo "(only the raw-wtype control failed — that is the bug being worked around)"
  exit 0
fi
[ "$FAIL" -gt 0 ] && { printf 'failed: %s\n' "${FAILED[*]}"; exit 1; }
exit 0

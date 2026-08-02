#!/usr/bin/env bash
# What ACTUALLY triggers the wtype keymap corruption?
# The "14+ distinct characters" model is contradicted by a 28-distinct shell
# command line typing cleanly. Test the competing hypotheses directly, all via
# RAW wtype (no hcu-type), one string per line in a single sink.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export SINK_DIR="/tmp/hcu-probe-$$"
# shellcheck source=/dev/null
source "$HERE/nested-sink.sh"
trap 'sink_stop; rm -rf "$SINK_DIR"' EXIT

NAMES=(); EXPECTED=()
t() { # name, text
  NAMES+=("$1"); EXPECTED+=("$2")
  WAYLAND_DISPLAY="$SINK_DISPLAY" wtype "$2" >/dev/null 2>&1
  sleep 0.25
  WAYLAND_DISPLAY="$SINK_DISPLAY" wtype -k Return
  sleep 0.25
}

sink_start || exit 1
sink_open run || exit 1
echo "=== trigger probe (raw wtype) ==="

t "lower-26"        "abcdefghijklmnopqrstuvwxyz"
t "UPPER-26"        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
t "lower-14"        "abcdefghijklmn"
t "UPPER-14"        "ABCDEFGHIJKLMN"
t "lower-13"        "abcdefghijklm"
t "UPPER-13"        "ABCDEFGHIJKLM"
t "digits-10"       "0123456789"
t "lower26+digits"  "abcdefghijklmnopqrstuvwxyz0123456789"
t "mixed-case-14"   "aBcDeFgHiJkLmN"
t "upper8"          "ABCDEFGH"
t "upper10"         "ABCDEFGHIJ"
t "upper12"         "ABCDEFGHIJKL"
t "punct-heavy"     'a!@#$%^&*()_+{}|:"<>?'
t "cmdline-like"    'git commit -m "fix: keymap overflow (N/O to Tab)"'

sink_close
mapfile -t GOT < <(cat "$SINK_FILE" 2>/dev/null)

printf '\n%-16s %-6s %s\n' "CASE" "UPPER" "RESULT"
for i in "${!NAMES[@]}"; do
  want="${EXPECTED[$i]}"; got="${GOT[$i]-<missing>}"
  nup=$(printf '%s' "$want" | grep -o '[A-Z]' | wc -l)
  ndist=$(printf '%s' "$want" | fold -w1 | sort -u | wc -l)
  if [ "$want" = "$got" ]; then
    printf '%-16s %-6s OK      (distinct=%s)\n' "${NAMES[$i]}" "$nup" "$ndist"
  else
    printf '%-16s %-6s CORRUPT (distinct=%s)\n    want=%q\n    got =%q\n' \
      "${NAMES[$i]}" "$nup" "$ndist" "$want" "$got"
  fi
done

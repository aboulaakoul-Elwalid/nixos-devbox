#!/usr/bin/env bash
# Find the exact boundary at which wtype's generated keymap starts corrupting.
# Types the first N distinct characters of the alphabet, for increasing N.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export SINK_DIR="/tmp/hcu-characterize-$$"
# shellcheck source=/dev/null
source "$HERE/nested-sink.sh"

trap 'sink_stop; rm -rf "$SINK_DIR"' EXIT

sink_start || exit 1

ALPHA="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghij"
RESULTS="$SINK_DIR/results.txt"
: > "$RESULTS"

for n in 5 8 10 12 13 14 15 16 18 20 24 30 36 40 46; do
  s="${ALPHA:0:$n}"
  sink_open "n$n" || continue
  WAYLAND_DISPLAY="$SINK_DISPLAY" wtype "$s"
  sink_close
  got=$(cat "$SINK_FILE" 2>/dev/null | tr -d '\n')
  if [ "$got" = "$s" ]; then
    printf '%-4s OK    %s\n' "$n" "$s" | tee -a "$RESULTS"
  else
    printf '%-4s BAD   want=%s\n          got =%s\n' "$n" "$s" "$got" | tee -a "$RESULTS"
  fi
done

echo
echo "=== summary ==="
grep -c OK  "$RESULTS" | xargs echo "clean lengths:"
grep -c BAD "$RESULTS" | xargs echo "corrupt lengths:"

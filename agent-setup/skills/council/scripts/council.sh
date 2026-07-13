#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: council.sh [--timeout DURATION]

Reads one evidence packet from stdin, consults Gemini, Opus, and Grok in
parallel, and prints labeled responses. Succeeds when at least one consultant
succeeds.

Lanes:
  - Gemini 3.1 Pro  via antigravity-consult
  - Claude Opus     via antigravity-consult
  - xAI Grok 4.5    via OpenCode (`opencode run -m xai/grok-4.5`)
EOF
}

timeout_duration="${AGY_COUNCIL_TIMEOUT:-${AGY_CONSULT_TIMEOUT:-10m}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      timeout_duration="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

packet="$(cat)"
[[ -n "${packet//[[:space:]]/}" ]] || {
  printf 'Council evidence packet is empty.\n' >&2
  exit 2
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
consult_script="${AGY_CONSULT_SCRIPT:-$script_dir/../../antigravity-consult/scripts/consult.sh}"
grok_script="${OPENCODE_GROK_CONSULT_SCRIPT:-$script_dir/consult-grok.sh}"

[[ -f "$consult_script" ]] || {
  printf 'Antigravity consultation wrapper not found: %s\n' "$consult_script" >&2
  exit 127
}
[[ -f "$grok_script" ]] || {
  printf 'Grok consultation wrapper not found: %s\n' "$grok_script" >&2
  exit 127
}

workdir="$(mktemp -d "${TMPDIR:-/tmp}/agy-council.XXXXXX")"
gemini_out="$workdir/gemini.out"
opus_out="$workdir/opus.out"
grok_out="$workdir/grok.out"

cleanup() {
  rm -f "$gemini_out" "$opus_out" "$grok_out"
  rmdir "$workdir" 2>/dev/null || true
}
trap cleanup EXIT

printf '%s\n' "$packet" | bash "$consult_script" --timeout "$timeout_duration" gemini >"$gemini_out" 2>&1 &
gemini_pid=$!
printf '%s\n' "$packet" | bash "$consult_script" --timeout "$timeout_duration" opus >"$opus_out" 2>&1 &
opus_pid=$!
printf '%s\n' "$packet" | bash "$grok_script" --timeout "$timeout_duration" >"$grok_out" 2>&1 &
grok_pid=$!

set +e
wait "$gemini_pid"
gemini_status=$?
wait "$opus_pid"
opus_status=$?
wait "$grok_pid"
grok_status=$?
set -e

printf '## Gemini 3.1 Pro\nStatus: %s\n\n' "$gemini_status"
cat "$gemini_out"
printf '\n\n## Claude Opus\nStatus: %s\n\n' "$opus_status"
cat "$opus_out"
printf '\n\n## xAI Grok 4.5\nStatus: %s\n\n' "$grok_status"
cat "$grok_out"
printf '\n'

if (( gemini_status != 0 && opus_status != 0 && grok_status != 0 )); then
  exit 1
fi

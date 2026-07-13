#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: consult.sh [--timeout DURATION] <gemini|opus>

Reads a consultation packet from stdin and prints the selected model's reply.
EOF
}

timeout_duration="${AGY_CONSULT_TIMEOUT:-10m}"
max_bytes="${AGY_CONSULT_MAX_BYTES:-51200}"

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
      break
      ;;
  esac
done

[[ $# -eq 1 ]] || { usage; exit 2; }

case "$1" in
  gemini|gemini-high)
    model="${AGY_GEMINI_MODEL:-Gemini 3.1 Pro (High)}"
    ;;
  opus|claude)
    model="${AGY_OPUS_MODEL:-Claude Opus 4.6 (Thinking)}"
    ;;
  *)
    printf 'Unknown consultant: %s\n' "$1" >&2
    usage
    exit 2
    ;;
esac

agy_bin="${AGY_BIN:-agy}"
command -v "$agy_bin" >/dev/null 2>&1 || {
  printf 'Antigravity CLI not found: %s\n' "$agy_bin" >&2
  exit 127
}

packet="$(cat)"
[[ -n "${packet//[[:space:]]/}" ]] || {
  printf 'Consultation packet is empty.\n' >&2
  exit 2
}

[[ "$max_bytes" =~ ^[1-9][0-9]*$ ]] || {
  printf 'AGY_CONSULT_MAX_BYTES must be a positive integer, got: %s\n' "$max_bytes" >&2
  exit 2
}

packet_bytes="$(printf '%s' "$packet" | wc -c | tr -d '[:space:]')"
if (( packet_bytes > max_bytes )); then
  printf 'Consultation packet is too large: %s bytes (limit: %s). Send focused evidence or raise AGY_CONSULT_MAX_BYTES deliberately.\n' \
    "$packet_bytes" "$max_bytes" >&2
  exit 2
fi

secret_pattern='-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----|(^|[^A-Za-z0-9])(AKIA|ASIA)[A-Z0-9]{16}([^A-Za-z0-9]|$)|(^|[^A-Za-z0-9])gh[pousr]_[A-Za-z0-9]{20,}([^A-Za-z0-9]|$)|(^|[^A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}([^A-Za-z0-9]|$)|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._~+/-]{12,}|(^|[^A-Za-z0-9])(password|passwd|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}'
if printf '%s\n' "$packet" | grep -Eiq -- "$secret_pattern"; then
  printf 'Consultation packet appears to contain a credential or private key. Redact it before consulting an external model.\n' >&2
  exit 3
fi

model_output="$("$agy_bin" models 2>&1)" || {
  printf 'Could not fetch the Antigravity model catalog.\n%s\n' "$model_output" >&2
  exit 4
}
model_catalog="$(printf '%s\n' "$model_output" | tr -d '\r' | sed $'s/\033\\[[0-9;?]*[ -\\/]*[@-~]//g')"
if ! printf '%s\n' "$model_catalog" | grep -Fqx -- "$model"; then
  printf 'Configured Antigravity model is unavailable: %s\nAvailable models:\n%s\n' \
    "$model" "$model_catalog" >&2
  exit 4
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/agy-consult.XXXXXX")"
cleanup() {
  rmdir "$workdir" 2>/dev/null || true
}
trap cleanup EXIT

cd "$workdir"
"$agy_bin" \
  --model "$model" \
  --sandbox \
  --print-timeout "$timeout_duration" \
  --print "$packet"

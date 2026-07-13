#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: consult-grok.sh [--timeout DURATION]

Reads a consultation packet from stdin and prints Grok's reply via OpenCode
(`opencode run -m xai/grok-4.5`). Used by Codex CLI / Claude Code council so
Grok is a real external lane, not a simulated persona.
EOF
}

timeout_duration="${OPENCODE_GROK_TIMEOUT:-${AGY_CONSULT_TIMEOUT:-10m}}"
max_bytes="${OPENCODE_GROK_MAX_BYTES:-${AGY_CONSULT_MAX_BYTES:-51200}}"
model="${OPENCODE_GROK_MODEL:-xai/grok-4.5}"

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
  printf 'Consultation packet is empty.\n' >&2
  exit 2
}

[[ "$max_bytes" =~ ^[1-9][0-9]*$ ]] || {
  printf 'OPENCODE_GROK_MAX_BYTES must be a positive integer, got: %s\n' "$max_bytes" >&2
  exit 2
}

packet_bytes="$(printf '%s' "$packet" | wc -c | tr -d '[:space:]')"
if (( packet_bytes > max_bytes )); then
  printf 'Consultation packet is too large: %s bytes (limit: %s). Send focused evidence or raise OPENCODE_GROK_MAX_BYTES deliberately.\n' \
    "$packet_bytes" "$max_bytes" >&2
  exit 2
fi

secret_pattern='-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----|(^|[^A-Za-z0-9])(AKIA|ASIA)[A-Z0-9]{16}([^A-Za-z0-9]|$)|(^|[^A-Za-z0-9])gh[pousr]_[A-Za-z0-9]{20,}([^A-Za-z0-9]|$)|(^|[^A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}([^A-Za-z0-9]|$)|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._~+/-]{12,}|(^|[^A-Za-z0-9])(password|passwd|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}'
if printf '%s\n' "$packet" | grep -Eiq -- "$secret_pattern"; then
  printf 'Consultation packet appears to contain a credential or private key. Redact it before consulting an external model.\n' >&2
  exit 3
fi

opencode_bin="${OPENCODE_BIN:-}"
if [[ -z "$opencode_bin" ]]; then
  if command -v opencode >/dev/null 2>&1; then
    opencode_bin="$(command -v opencode)"
  elif [[ -x /home/elwalid/.local/bin/opencode ]]; then
    opencode_bin="/home/elwalid/.local/bin/opencode"
  elif [[ -x /home/elwalid/.npm-global/bin/opencode ]]; then
    opencode_bin="/home/elwalid/.npm-global/bin/opencode"
  else
    printf 'OpenCode CLI not found. Install opencode or set OPENCODE_BIN.\n' >&2
    exit 127
  fi
fi

prompt="$(cat <<EOF
You are oracle-grok, a read-only council member (xAI Grok).

CRITICAL RULES:
- Answer only from the evidence packet below plus general knowledge.
- Do not ask clarifying questions.
- Do not invent repository facts not present in the packet.
- Return only the structured recommendation.

Response shape:

Recommended option
<answer>

Strongest reasons
<concise bullets>

Risks and tradeoffs
<concise bullets>

Default choice
<one clear choice>

Evidence packet:
${packet}
EOF
)"

workdir="$(mktemp -d "${TMPDIR:-/tmp}/opencode-grok-consult.XXXXXX")"
out_file="$workdir/out.txt"
cleanup() {
  rm -f "$out_file"
  rmdir "$workdir" 2>/dev/null || true
}
trap cleanup EXIT

# Prefer non-interactive run. Timeout bounds hung auth/provider calls.
set +e
if command -v timeout >/dev/null 2>&1; then
  timeout "$timeout_duration" "$opencode_bin" run -m "$model" "$prompt" >"$out_file" 2>&1
else
  "$opencode_bin" run -m "$model" "$prompt" >"$out_file" 2>&1
fi
status=$?
set -e

if [[ ! -s "$out_file" ]]; then
  printf 'Grok consultation produced no output (status %s).\n' "$status" >&2
  exit "${status:-1}"
fi

cat "$out_file"
printf '\n'
exit "$status"

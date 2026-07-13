#!/usr/bin/env bash
set -euo pipefail

if command -v wrangler >/dev/null 2>&1; then
  WRANGLER=(wrangler)
else
  WRANGLER=(npx --yes wrangler@latest)
fi

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" && -f "$HOME/.config/cloudflare/env" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.config/cloudflare/env"
fi

mask_output() {
  sed -E \
    -e 's/[0-9a-f]{32}/<account-id>/g' \
    -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<email>/g'
}

run_check() {
  local label="$1"
  shift

  printf '\n== %s ==\n' "$label"
  if "$@" 2>&1 | mask_output; then
    printf 'status: ok\n'
  else
    local exit_code=$?
    printf 'status: failed (%s)\n' "$exit_code"
    return "$exit_code"
  fi
}

run_capability_probe() {
  local label="$1"
  shift

  printf '\n== %s ==\n' "$label"
  if "$@" 2>&1 | mask_output; then
    printf 'status: ok\n'
  else
    local exit_code=$?
    printf 'status: unavailable-or-insufficient-token-scope (%s)\n' "$exit_code"
  fi
}

run_api_check() {
  local label="$1"
  local url="$2"
  local tmp
  local status

  tmp="$(mktemp)"
  printf '\n== %s ==\n' "$label"

  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    printf 'CLOUDFLARE_API_TOKEN is not set\n'
    printf 'status: failed\n'
    rm -f "$tmp"
    return 1
  fi

  status="$(curl -sS -o "$tmp" -w '%{http_code}' -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "$url" || true)"
  mask_output <"$tmp"
  if [[ "$status" == "200" ]] && grep -q '"success":true' "$tmp"; then
    printf 'status: ok\n'
  else
    printf 'http_status: %s\n' "$status"
    printf 'status: failed\n'
    rm -f "$tmp"
    return 1
  fi

  rm -f "$tmp"
}

run_optional_r2_check() {
  local tmp
  tmp="$(mktemp)"

  printf '\n== r2 bucket list ==\n'
  if "${WRANGLER[@]}" r2 bucket list >"$tmp" 2>&1; then
    mask_output <"$tmp"
    printf 'status: ok\n'
  elif grep -Eq 'code: 10042|enable R2' "$tmp"; then
    mask_output <"$tmp"
    printf 'status: known-account-side-setup-needed (R2 is not enabled)\n'
  else
    mask_output <"$tmp"
    printf 'status: unavailable-or-insufficient-token-scope\n'
    rm -f "$tmp"
    return 0
  fi

  rm -f "$tmp"
}

printf 'Cloudflare local verification\n'
printf 'wrangler_command: %s\n' "${WRANGLER[*]}"

run_check 'wrangler version' "${WRANGLER[@]}" --version
run_api_check 'api token verify' 'https://api.cloudflare.com/client/v4/user/tokens/verify'
run_api_check 'asayl.co zone lookup' 'https://api.cloudflare.com/client/v4/zones?name=asayl.co'
run_capability_probe 'wrangler whoami' "${WRANGLER[@]}" whoami
run_capability_probe 'pages project list' "${WRANGLER[@]}" pages project list
run_capability_probe 'kv namespace list' "${WRANGLER[@]}" kv namespace list
run_capability_probe 'd1 list' "${WRANGLER[@]}" d1 list
run_optional_r2_check

printf '\n== cloudflared binary ==\n'
if command -v cloudflared >/dev/null 2>&1; then
  cloudflared --version 2>&1 | mask_output
  printf 'status: ok\n'
else
  printf 'cloudflared is not installed in PATH\n'
  printf 'status: missing\n'
fi

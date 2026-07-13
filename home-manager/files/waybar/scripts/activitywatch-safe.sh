#!/usr/bin/env bash
set -euo pipefail
if out=$(/home/elwalid/.config/waybar/scripts/activitywatch-status.sh 2>/dev/null); then
  if jq -e . >/dev/null 2>&1 <<<"$out"; then
    jq -c '.' <<<"$out"
    exit 0
  fi
fi
echo '{"text":"󰥔 ?","tooltip":"ActivityWatch unavailable","class":"idle"}'

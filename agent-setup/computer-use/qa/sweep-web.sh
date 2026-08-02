#!/usr/bin/env bash
# Sweep a deployed web app: click each control, check it responds, and check
# the network/console underneath.
#
# Run it against an app you KNOW is healthy first. An oracle that has only seen
# broken things is not known to discriminate, and a QA tool that cries wolf on a
# working app gets ignored — which is worse than having no tool.
#
#   ./qa/sweep-web.sh <url> [max-controls]
set -uo pipefail
URL="${1:?usage: sweep-web.sh <url> [max-controls]}"
MAX="${2:-8}"
PWCLI="${PWCLI:-$HOME/.codex/skills/playwright/scripts/playwright_cli.sh}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WS="$(mktemp -d /tmp/qa-web-XXXXXX)"
SESS="web-$$"
trap '"$PWCLI" -s="$SESS" close >/dev/null 2>&1; rm -rf "$WS"' EXIT

"$ROOT/bin/pw-init" "$WS" >/dev/null || { echo "pw-init failed"; exit 1; }
cd "$WS"

pw() { timeout 150 "$PWCLI" -s="$SESS" "$@" 2>&1; }
raw() { timeout 90 "$PWCLI" -s="$SESS" --raw eval "$1" 2>/dev/null | tail -1; }

pw open "$URL" >/dev/null

# Collect refs + labels once, up front: clicking mutates the page, so refs
# gathered after the first navigation would drift.
mapfile -t CTRLS < <(pw snapshot | grep -oE '(link|button) "[^"]{3,60}" \[ref=e[0-9]+\]' \
                     | sed -E 's/^(link|button) "([^"]*)" \[ref=(e[0-9]+)\]/\3|\2/' | head -"$MAX")

printf '%-6s %-44s %-12s %s\n' "REF" "CONTROL" "RESPONDS" "NETWORK/CONSOLE"
printf '%s\n' "--------------------------------------------------------------------------------------"

FINDINGS=0
for entry in "${CTRLS[@]}"; do
  ref="${entry%%|*}"; label="${entry#*|}"
  pw open "$URL" >/dev/null            # fresh state per control
  b_len="$(raw '() => document.body.innerText.length')"
  b_url="$(raw '() => location.href')"

  pw click "$ref" >/dev/null
  sleep 3

  a_len="$(raw '() => document.body.innerText.length')"
  a_url="$(raw '() => location.href')"
  moved="no"; { [ "$b_len" != "$a_len" ] || [ "$b_url" != "$a_url" ]; } && moved="yes"

  # network + console evidence, benign noise filtered
  bad="$(pw console error | grep -viE 'favicon|ERR_NETWORK_CHANGED' | grep -cE '^\[ERROR\]' || true)"
  fourohfour="$(pw requests 2>/dev/null | grep -cE '\[(4[0-9]{2}|5[0-9]{2})\]' || true)"

  note=""
  [ "${bad:-0}" -gt 0 ] && note="${bad} console err"
  [ "${fourohfour:-0}" -gt 0 ] && note="${note}${note:+, }${fourohfour} http 4xx/5xx"
  [ -z "$note" ] && note="clean"
  [ "$moved" = "no" ] && { note="$note  <- NO RESPONSE"; FINDINGS=$((FINDINGS+1)); }
  [ "${bad:-0}" -gt 0 ] || [ "${fourohfour:-0}" -gt 0 ] && FINDINGS=$((FINDINGS+1))

  printf '%-6s %-44s %-12s %s\n' "$ref" "${label:0:44}" "$moved" "$note"
done

echo
echo "controls swept: ${#CTRLS[@]} | findings: $FINDINGS"

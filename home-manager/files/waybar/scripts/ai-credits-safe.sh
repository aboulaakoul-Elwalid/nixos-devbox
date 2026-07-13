#!/usr/bin/env bash
set -euo pipefail

TOKSCALE="/home/elwalid/.cache/.bun/bin/tokscale"
CACHE_DIR="${XDG_CACHE_HOME:-/home/elwalid/.cache}/waybar"
CACHE_FILE="$CACHE_DIR/tokens-today.json"
LOCK_FILE="$CACHE_DIR/tokens-today.lock"
CACHE_TTL_SECONDS=3600

tokens_text="..."
tokens_tooltip="OpenCode tokens today refresh pending"

mkdir -p "$CACHE_DIR"

refresh_tokens_cache() {
  [[ -x "$TOKSCALE" ]] || return 0

  (
    flock -n 9 || exit 0
    tmp="${CACHE_FILE}.$$"
    if "$TOKSCALE" models --opencode --today --json --no-spinner >"$tmp" 2>/dev/null; then
      mv "$tmp" "$CACHE_FILE"
    else
      rm -f "$tmp"
    fi
  ) 9>"$LOCK_FILE" >/dev/null 2>&1 &
}

cache_is_fresh() {
  [[ -s "$CACHE_FILE" ]] || return 1
  now="$(date +%s)"
  updated="$(stat -c %Y "$CACHE_FILE" 2>/dev/null || printf 0)"
  (( now - updated < CACHE_TTL_SECONDS ))
}

if ! cache_is_fresh; then
  refresh_tokens_cache
fi

if [[ -s "$CACHE_FILE" ]]; then
  if tokens_json="$(jq -c . "$CACHE_FILE" 2>/dev/null)"; then
    tokens_text="$(jq -r '
      def compact:
        if . >= 1000000000 then ((. / 1000000000 * 10 | round / 10 | tostring) + "B")
        elif . >= 1000000 then ((. / 1000000 * 10 | round / 10 | tostring) + "M")
        elif . >= 1000 then ((. / 1000 * 10 | round / 10 | tostring) + "K")
        else tostring
        end;
      (.totalInput + .totalOutput + .totalCacheRead + .totalCacheWrite) | compact
    ' <<<"$tokens_json" 2>/dev/null || printf '...')"
    tokens_tooltip="$(jq -r '
      def compact:
        if . >= 1000000000 then ((. / 1000000000 * 10 | round / 10 | tostring) + "B")
        elif . >= 1000000 then ((. / 1000000 * 10 | round / 10 | tostring) + "M")
        elif . >= 1000 then ((. / 1000 * 10 | round / 10 | tostring) + "K")
        else tostring
        end;
      "OpenCode tokens today\n" +
      "Total: " + ((.totalInput + .totalOutput + .totalCacheRead + .totalCacheWrite) | compact) + "\n" +
      "Input: " + (.totalInput | compact) + "\n" +
      "Output: " + (.totalOutput | compact) + "\n" +
      "Cache read: " + (.totalCacheRead | compact) + "\n" +
      "Cost: $" + (.totalCost * 100 | round / 100 | tostring)
    ' <<<"$tokens_json" 2>/dev/null || printf 'OpenCode tokens today unavailable')"
  fi
fi

if out=$(/home/elwalid/.local/bin/ai-credits-waybar 2>/dev/null); then
  if jq -e . >/dev/null 2>&1 <<<"$out"; then
    jq -c --arg tokens "$tokens_text" --arg tokstt "$tokens_tooltip" '
      .text = (" " + ((((.text | tostring | split(" C "))[1]) // "?") | sub("^ +"; "")) + " · " + $tokens) |
      .tooltip = ($tokstt + "\n─────\n" + (.tooltip // "AI credits unavailable"))
    ' <<<"$out"
    exit 0
  fi
fi

jq -nc --arg tokens "$tokens_text" --arg tooltip "$tokens_tooltip" '{text:(" · " + $tokens), tooltip:$tooltip, class:"ai-credits-warning"}'

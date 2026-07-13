#!/usr/bin/env bash
# ActivityWatch status for waybar (Nix-safe: no python requests dependency)
set -euo pipefail

api="http://localhost:5600/api/0"
if ! curl -fsS "$api/info" >/dev/null 2>&1; then
  echo '{"text": "󰥔 0m", "tooltip": "ActivityWatch: Offline", "class": "idle"}'
  exit 0
fi

host="$(hostname)"
bucket="aw-watcher-window_${host}"
start="$(date +%Y-%m-%dT00:00:00%:z)"
end="$(date --iso-8601=seconds)"

json="$(curl -fsS --get "$api/buckets/${bucket}/events" --data-urlencode "start=${start}" --data-urlencode "end=${end}" 2>/dev/null || true)"
if [[ -z "$json" ]]; then
  echo '{"text": "󰥔 ?", "tooltip": "ActivityWatch: bucket not found", "class": "idle"}'
  exit 0
fi

seconds="$(jq -r '[.[].duration] | add // 0' <<<"$json" 2>/dev/null || echo 0)"
if [[ -z "$seconds" || "$seconds" == "null" ]]; then
  seconds=0
fi

seconds_int=$(( ${seconds%.*} ))
hours=$(( seconds_int / 3600 ))
minutes=$(( (seconds_int % 3600) / 60 ))
if (( hours > 0 )); then
  active_time="${hours}h${minutes}m"
elif (( minutes > 0 )); then
  active_time="${minutes}m"
elif (( seconds_int > 0 )); then
  active_time="${seconds_int}s"
else
  active_time="0m"
fi

if [[ "$active_time" == "0m" ]]; then
  echo "{\"text\": \"󰥔 ${active_time}\", \"tooltip\": \"Active: ${active_time}\", \"class\": \"idle\"}"
else
  echo "{\"text\": \"󰥔 ${active_time}\", \"tooltip\": \"Active: ${active_time}\", \"class\": \"active\"}"
fi

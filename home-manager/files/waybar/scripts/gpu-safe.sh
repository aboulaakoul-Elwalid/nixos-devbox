#!/usr/bin/env bash
set -euo pipefail

if ! out=$(/run/current-system/sw/bin/nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,name --format=csv,noheader,nounits 2>/dev/null); then
  echo '{"text":"󰢮 ?","tooltip":"GPU unavailable","class":"warning"}'
  exit 0
fi

IFS=',' read -r util mem_used mem_total temp name <<< "$out"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

util=$(trim "$util")
mem_used=$(trim "$mem_used")
mem_total=$(trim "$mem_total")
temp=$(trim "$temp")
name=$(trim "$name")

mem_pct=0
if [[ "$mem_total" =~ ^[0-9]+$ ]] && (( mem_total > 0 )); then
  mem_pct=$((mem_used * 100 / mem_total))
fi

class="normal"
if (( util >= 80 || temp >= 80 )); then
  class="critical"
elif (( util >= 50 || temp >= 70 )); then
  class="warning"
fi

jq -nc \
  --arg text "󰢮 ${util}%" \
  --arg tooltip "$(printf '%s\n- Load: %s%%\n- VRAM: %s MiB / %s MiB (%s%%)\n- Temp: %sC' "$name" "$util" "$mem_used" "$mem_total" "$mem_pct" "$temp")" \
  --arg class "$class" \
  '{text:$text,tooltip:$tooltip,class:$class}'

#!/usr/bin/env bash

waybar_cache_dir() {
  printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
}

waybar_cache_file() {
  local key="$1"
  printf '%s/%s.json\n' "$(waybar_cache_dir)" "$key"
}

waybar_cache_is_fresh() {
  local file="$1"
  local ttl="$2"
  [[ -s "$file" ]] || return 1
  local now updated
  now="$(date +%s)"
  updated="$(stat -c %Y "$file" 2>/dev/null || printf 0)"
  (( now - updated < ttl ))
}

waybar_cache_refresh_bg() {
  local key="$1"
  local ttl="$2"
  shift 2
  local dir file lock
  dir="$(waybar_cache_dir)"
  file="$dir/$key.json"
  lock="$dir/$key.lock"
  mkdir -p "$dir"
  if waybar_cache_is_fresh "$file" "$ttl"; then
    return 0
  fi
  (
    flock -n 9 || exit 0
    local tmp
    tmp="$file.$$"
    if "$@" >"$tmp" 2>/dev/null; then
      mv "$tmp" "$file"
    else
      rm -f "$tmp"
    fi
  ) 9>"$lock" >/dev/null 2>&1 &
}

#!/run/current-system/sw/bin/bash

set -euo pipefail

PATH="$HOME/.local/bin:/run/current-system/sw/bin:$PATH"

STATE_DIR="$HOME/.local/state/opencode/restore"
LIVE_DIR="$STATE_DIR/live"
SNAPSHOT_FILE="$STATE_DIR/restore-snapshot.json"
LOCK_FILE="$STATE_DIR/save.lock"
LOG_FILE="/tmp/opencode-session-save.log"
JQ_BIN="/run/current-system/sw/bin/jq"

mkdir -p "$LIVE_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$1" >>"$LOG_FILE"
}

main() {
  local temp_dir sessions_array_file snapshot_tmp snapshot_saved_at live_file pid

  exec 9>"$LOCK_FILE"
  flock -n 9 || exit 0

  : >"$LOG_FILE"
  log "Saving active OpenCode sessions"

  temp_dir="$(mktemp -d "$STATE_DIR/save.XXXXXX")"
  sessions_array_file="$temp_dir/sessions.json"
  snapshot_tmp="$temp_dir/restore-snapshot.json"
  snapshot_saved_at="$(date --iso-8601=seconds)"

  shopt -s nullglob
  session_files=("$LIVE_DIR"/*.json)
  shopt -u nullglob

  valid_files=()
  for live_file in "${session_files[@]}"; do
    pid="$($JQ_BIN -r '.pid // empty' "$live_file" 2>/dev/null || true)"
    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
      continue
    fi

    if [[ "$($JQ_BIN -r '.sessionID // empty' "$live_file" 2>/dev/null || true)" == "" ]]; then
      continue
    fi

    valid_files+=("$live_file")
  done

  if [[ ${#valid_files[@]} -gt 0 ]]; then
    "$JQ_BIN" -s '.' "${valid_files[@]}" >"$sessions_array_file"
  else
    printf '[]\n' >"$sessions_array_file"
  fi

  "$JQ_BIN" -n \
    --arg savedAt "$snapshot_saved_at" \
    --slurpfile sessions "$sessions_array_file" \
    '{savedAt: $savedAt, sessions: $sessions[0]}' >"$snapshot_tmp"

  mv "$snapshot_tmp" "$SNAPSHOT_FILE"
  rm -rf "$temp_dir"

  log "Snapshot written to $SNAPSHOT_FILE"
}

main "$@"

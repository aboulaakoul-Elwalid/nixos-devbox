#!/run/current-system/sw/bin/bash

set -euo pipefail

PATH="$HOME/.local/bin:/run/current-system/sw/bin:$PATH"

STATE_DIR="$HOME/.local/state/opencode/restore"
SNAPSHOT_FILE="$STATE_DIR/restore-snapshot.json"
INFLIGHT_FILE="$STATE_DIR/restore-snapshot.inflight.json"
LAST_FILE="$STATE_DIR/restore-snapshot.last-restored.json"
LOCK_FILE="$STATE_DIR/restore.lock"
LOG_FILE="/tmp/opencode-session-restore.log"
JQ_BIN="/run/current-system/sw/bin/jq"

mkdir -p "$STATE_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$1" >>"$LOG_FILE"
}

wait_for_hyprland() {
  for _ in {1..60}; do
    if hyprctl monitors >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done

  return 1
}

has_instance_window() {
  local instance="$1"

  hyprctl clients -j 2>/dev/null | "$JQ_BIN" -e --arg instance "$instance" '
    any(.[]; (.initialTitle // "") == ("OpenCode::" + $instance))
  ' >/dev/null 2>&1
}

main() {
  local source_file temp_dir valid_ids_file entries_file entry
  local session_id directory instance restored=0

  exec 9>"$LOCK_FILE"
  flock -n 9 || exit 0

  : >"$LOG_FILE"
  log "Restoring OpenCode sessions"

  wait_for_hyprland || {
    log "Hyprland not ready"
    exit 1
  }

  if [[ -f "$SNAPSHOT_FILE" ]]; then
    mv "$SNAPSHOT_FILE" "$INFLIGHT_FILE"
    source_file="$INFLIGHT_FILE"
  elif [[ -f "$INFLIGHT_FILE" ]]; then
    source_file="$INFLIGHT_FILE"
  else
    log "No restore snapshot found"
    exit 0
  fi

  temp_dir="$(mktemp -d "$STATE_DIR/restore.XXXXXX")"
  valid_ids_file="$temp_dir/valid-ids.txt"
  entries_file="$temp_dir/entries.jsonl"

  opencode session list --format json | "$JQ_BIN" -r '.[].id' >"$valid_ids_file"
  "$JQ_BIN" -c '.sessions[]?' "$source_file" >"$entries_file"

  declare -A seen_ids=()

  while IFS= read -r entry; do
    session_id="$(printf '%s\n' "$entry" | "$JQ_BIN" -r '.sessionID // empty')"
    directory="$(printf '%s\n' "$entry" | "$JQ_BIN" -r '.directory // empty')"
    instance="$(printf '%s\n' "$entry" | "$JQ_BIN" -r '.instance // empty')"

    [[ -z "$session_id" || -z "$directory" || -z "$instance" ]] && {
      log "Skipping incomplete snapshot entry"
      continue
    }

    if [[ -n "${seen_ids[$session_id]:-}" ]]; then
      continue
    fi

    if ! grep -Fxq -- "$session_id" "$valid_ids_file"; then
      log "Skipping stale session: $session_id"
      continue
    fi

    if has_instance_window "$instance"; then
      log "Already open: $session_id"
      seen_ids[$session_id]=1
      continue
    fi

    log "Reopening session: $session_id"
    OPENCODE_RESTORE_INSTANCE="$instance" OPENCODE_RESTORE_DIRECTORY="$directory" \
      uwsm-app -- /run/current-system/sw/bin/kitty --title "OpenCode::${instance}" --directory "$directory" /home/elwalid/.local/bin/oc --session "$session_id" >/dev/null 2>&1 &
    seen_ids[$session_id]=1
    restored=$((restored + 1))
    sleep 0.75
  done <"$entries_file"

  mv "$source_file" "$LAST_FILE"
  rm -rf "$temp_dir"

  log "Restored $restored OpenCode session(s)"
}

main "$@"

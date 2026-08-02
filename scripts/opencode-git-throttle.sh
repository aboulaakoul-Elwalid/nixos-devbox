#!/usr/bin/env bash
set -euo pipefail

TARGET='/home/elwalid/.local/share/opencode/snapshot/global'

pids=$(pgrep -f "git .*${TARGET}" || true)
if [[ -z "${pids}" ]]; then
  exit 0
fi

for pid in ${pids}; do
  # Best-effort: ignore errors if process exits between commands
  renice -n 15 -p "${pid}" >/dev/null 2>&1 || true
  if command -v ionice >/dev/null 2>&1; then
    ionice -c2 -n7 -p "${pid}" >/dev/null 2>&1 || true
  fi
  done

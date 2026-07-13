#!/usr/bin/env bash
# hypr-close-window.sh - Save window info before closing, enabling undo
# Usage: hypr-close-window.sh
# 
# Saves the active window's command to a stack file before closing it.
# Use hypr-restore-window.sh to restore the last closed window.

set -euo pipefail

STACK_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-closed-windows.stack"
MAX_STACK_SIZE=20

# Get active window info
WINDOW_JSON=$(hyprctl activewindow -j 2>/dev/null) || {
    # No active window, just exit
    exit 0
}

# Parse window info
PID=$(echo "$WINDOW_JSON" | jq -r '.pid // empty')
CLASS=$(echo "$WINDOW_JSON" | jq -r '.class // empty')
TITLE=$(echo "$WINDOW_JSON" | jq -r '.title // empty')
WORKSPACE=$(echo "$WINDOW_JSON" | jq -r '.workspace.id // empty')

if [[ -z "$PID" || "$PID" == "null" || "$PID" -le 0 ]]; then
    # No valid PID, just close
    hyprctl dispatch killactive
    exit 0
fi

# Get the command line used to start this process
CMDLINE=""
if [[ -f "/proc/$PID/cmdline" ]]; then
    # cmdline uses null bytes as separators
    CMDLINE=$(tr '\0' ' ' < "/proc/$PID/cmdline" | sed 's/ $//')
fi

# Get working directory for terminals
CWD=""
if [[ -d "/proc/$PID/cwd" ]]; then
    CWD=$(readlink -f "/proc/$PID/cwd" 2>/dev/null) || true
fi

# Skip if we couldn't get a command
if [[ -z "$CMDLINE" ]]; then
    hyprctl dispatch killactive
    exit 0
fi

# Create stack file if it doesn't exist
touch "$STACK_FILE"

# Build the restore entry as compact JSON (single line) for reliable parsing
# Include class, workspace, cwd, and full command
ENTRY=$(jq -cn \
    --arg class "$CLASS" \
    --arg title "$TITLE" \
    --arg workspace "$WORKSPACE" \
    --arg cwd "$CWD" \
    --arg cmd "$CMDLINE" \
    '{class: $class, title: $title, workspace: $workspace, cwd: $cwd, cmd: $cmd}')

# Prepend to stack (newest first)
{
    echo "$ENTRY"
    head -n $((MAX_STACK_SIZE - 1)) "$STACK_FILE" 2>/dev/null || true
} > "${STACK_FILE}.tmp"
mv "${STACK_FILE}.tmp" "$STACK_FILE"

# Now close the window
hyprctl dispatch killactive

# Optional: notify user (uncomment if you want notifications)
# notify-send -t 1500 "Window closed" "$CLASS saved to restore stack"

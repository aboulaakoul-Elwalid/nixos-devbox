#!/usr/bin/env bash
# hypr-restore-window.sh - Restore the last closed window
# Usage: hypr-restore-window.sh
#
# Pops the last entry from the closed windows stack and relaunches it.

set -euo pipefail

STACK_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-closed-windows.stack"

if [[ ! -f "$STACK_FILE" ]] || [[ ! -s "$STACK_FILE" ]]; then
    notify-send -t 2000 "No windows to restore" "The closed windows stack is empty"
    exit 0
fi

# Read the first entry (most recent)
ENTRY=$(head -n 1 "$STACK_FILE")

if [[ -z "$ENTRY" ]]; then
    notify-send -t 2000 "No windows to restore" "The closed windows stack is empty"
    exit 0
fi

# Remove the first entry from the stack
tail -n +2 "$STACK_FILE" > "${STACK_FILE}.tmp" 2>/dev/null || true
mv "${STACK_FILE}.tmp" "$STACK_FILE"

# Parse the entry
CLASS=$(echo "$ENTRY" | jq -r '.class // empty')
WORKSPACE=$(echo "$ENTRY" | jq -r '.workspace // empty')
CWD=$(echo "$ENTRY" | jq -r '.cwd // empty')
CMD=$(echo "$ENTRY" | jq -r '.cmd // empty')

if [[ -z "$CMD" ]]; then
    notify-send -t 2000 "Restore failed" "No command found for the last closed window"
    exit 1
fi

# Special handling for different application types
case "$CLASS" in
    # Terminals - restore with working directory
    com.mitchellh.ghostty|ghostty)
        if [[ -n "$CWD" && -d "$CWD" ]]; then
            uwsm app -- ghostty --working-directory="$CWD" &
        else
            uwsm app -- ghostty &
        fi
        ;;
    
    Alacritty|alacritty)
        if [[ -n "$CWD" && -d "$CWD" ]]; then
            uwsm app -- alacritty --working-directory "$CWD" &
        else
            uwsm app -- alacritty &
        fi
        ;;
    
    kitty)
        if [[ -n "$CWD" && -d "$CWD" ]]; then
            uwsm app -- kitty --directory "$CWD" &
        else
            uwsm app -- kitty &
        fi
        ;;
    
    foot)
        if [[ -n "$CWD" && -d "$CWD" ]]; then
            uwsm app -- foot --working-directory="$CWD" &
        else
            uwsm app -- foot &
        fi
        ;;
    
    # For other apps, try to run the original command
    *)
        # Run with uwsm app for proper Wayland session integration
        # Use eval to handle complex command lines with spaces/quotes
        eval "uwsm app -- $CMD" &
        ;;
esac

# Move to the workspace where the window was (optional)
if [[ -n "$WORKSPACE" && "$WORKSPACE" != "null" ]]; then
    sleep 0.3
    hyprctl dispatch workspace "$WORKSPACE" 2>/dev/null || true
fi

notify-send -t 1500 "Window restored" "$CLASS"

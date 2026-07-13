#!/bin/bash
# Manual trigger to save today's ActivityWatch stats to vault
# Can be bound to a keybinding like Super+Shift+S

# Run the script for today
/home/elwalid/.local/bin/aw-to-vault.py today

# Show notification (optional - requires dunst or similar)
if command -v notify-send &> /dev/null; then
    notify-send "ActivityWatch" "Daily stats saved to vault!" -i clock
fi

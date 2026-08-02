#!/bin/bash
# Watchdog script to restart hyprshell if it becomes unresponsive

check_hyprshell() {
    # Check if socket exists and is responsive
    SOCKET=$(ls /run/user/1000/hypr/*/hyprshell.sock 2>/dev/null | head -1)
    if [ -z "$SOCKET" ] || [ ! -S "$SOCKET" ]; then
        echo "hyprshell socket not found, restarting..."
        systemctl --user restart hyprshell.service
        return 1
    fi
    return 0
}

# Run check
check_hyprshell

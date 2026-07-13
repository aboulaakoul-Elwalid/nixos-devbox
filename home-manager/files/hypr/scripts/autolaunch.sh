#!/bin/bash

# Crucial: Launches the daemon and ensures environment variables are set in the shell.
# 'eval' is the key to setting $GNOME_KEYRING_CONTROL.
eval $(/usr/bin/gnome-keyring-daemon --start --components=secrets,ssh)

# Start the authentication agent (Polkit)
/usr/lib/polkit-gnome/polkit-agent-1 &

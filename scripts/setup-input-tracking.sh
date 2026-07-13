#!/bin/bash
# Setup script for input tracking

echo "Setting up ActivityWatch Input Tracking..."
echo

# Check if python-evdev is installed
if ! pacman -Q python-evdev &>/dev/null; then
    echo "Installing python-evdev..."
    sudo pacman -S --needed python-evdev
else
    echo "✓ python-evdev is installed"
fi

# Check if user is in input group
if ! groups | grep -q input; then
    echo
    echo "Adding $USER to 'input' group..."
    sudo usermod -aG input $USER
    echo
    echo "⚠️  You need to LOG OUT and LOG BACK IN for group changes to take effect!"
    echo
else
    echo "✓ User is in 'input' group"
fi

# Create systemd service
echo
echo "Creating systemd service..."
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/aw-input-tracker.service << 'EOF'
[Unit]
Description=ActivityWatch Input Tracker
After=aw-server.service
Requires=aw-server.service

[Service]
ExecStart=/home/elwalid/.local/bin/aw-input-tracker.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

echo "✓ Service file created"

# Reload and enable
echo
echo "Enabling service..."
systemctl --user daemon-reload
systemctl --user enable aw-input-tracker
echo "✓ Service enabled"

echo
echo "Setup complete!"
echo
echo "To start tracking:"
echo "  systemctl --user start aw-input-tracker"
echo
echo "To check status:"
echo "  systemctl --user status aw-input-tracker"
echo
echo "⚠️  Remember: If you were just added to the input group,"
echo "    you MUST log out and log back in first!"

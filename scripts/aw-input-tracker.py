#!/usr/bin/env python3
"""
Input Activity Tracker for ActivityWatch
Tracks keyboard and mouse events without keylogging
Sends aggregate stats to ActivityWatch
"""

import sys
import time
import json
import math
from datetime import datetime, timezone
from collections import defaultdict

try:
    from evdev import InputDevice, categorize, ecodes, list_devices
except ImportError:
    print("Error: python-evdev is required")
    print("Install with: sudo pacman -S python-evdev")
    sys.exit(1)

try:
    from aw_core.models import Event
    from aw_client import ActivityWatchClient
except ImportError:
    print("Error: aw-client is required")
    print("Install with: pip install aw-client")
    sys.exit(1)


class InputTracker:
    def __init__(self):
        # Initialize ActivityWatch client
        self.client = ActivityWatchClient("aw-watcher-input", testing=False)
        self.bucket_id = f"{self.client.client_name}_{self.client.client_hostname}"
        self.client.create_bucket(self.bucket_id, event_type="inputstats", queued=True)

        # Tracking variables
        self.reset_stats()
        self.last_mouse_pos = (0, 0)
        self.last_heartbeat = time.time()
        self.heartbeat_interval = 60  # Send stats every 60 seconds

        # Device discovery
        self.keyboard_devices = []
        self.mouse_devices = []
        self.discover_devices()

    def reset_stats(self):
        """Reset current stats counters"""
        self.stats = {
            "keypresses": 0,
            "mouse_clicks": 0,
            "mouse_distance_px": 0,
            "mouse_scrolls": 0
        }

    def discover_devices(self):
        """Find keyboard and mouse devices"""
        print("Discovering input devices...")

        for device_path in list_devices():
            try:
                device = InputDevice(device_path)
                capabilities = device.capabilities()

                # Check if it's a keyboard (has key events)
                if ecodes.EV_KEY in capabilities:
                    keys = capabilities[ecodes.EV_KEY]
                    # Real keyboards have letter keys
                    if ecodes.KEY_A in keys or ecodes.KEY_SPACE in keys:
                        self.keyboard_devices.append(device)
                        print(f"  Keyboard: {device.name}")

                # Check if it's a mouse (has relative movement or buttons)
                if ecodes.EV_REL in capabilities:
                    self.mouse_devices.append(device)
                    print(f"  Mouse: {device.name}")

            except (OSError, PermissionError) as e:
                print(f"  Skipped {device_path}: {e}")

        if not self.keyboard_devices and not self.mouse_devices:
            print("\nError: No input devices found!")
            print("Make sure you have permissions to read /dev/input/*")
            print("Add your user to the 'input' group:")
            print("  sudo usermod -aG input $USER")
            print("Then log out and back in.")
            sys.exit(1)

    def send_heartbeat(self):
        """Send current stats to ActivityWatch"""
        if all(v == 0 for v in self.stats.values()):
            return  # Don't send empty stats

        # Convert pixel distance to feet (approximate)
        # Average monitor DPI is ~96, so 96 pixels = 1 inch
        distance_inches = self.stats["mouse_distance_px"] / 96
        distance_feet = distance_inches / 12
        distance_meters = distance_feet * 0.3048

        event_data = {
            "keypresses": self.stats["keypresses"],
            "mouse_clicks": self.stats["mouse_clicks"],
            "mouse_distance_px": self.stats["mouse_distance_px"],
            "mouse_distance_ft": round(distance_feet, 1),
            "mouse_distance_m": round(distance_meters, 1),
            "mouse_scrolls": self.stats["mouse_scrolls"]
        }

        event = Event(
            timestamp=datetime.now(timezone.utc),
            data=event_data
        )

        self.client.heartbeat(
            self.bucket_id,
            event,
            pulsetime=self.heartbeat_interval + 5,
            queued=True
        )

        print(f"[{datetime.now().strftime('%H:%M:%S')}] Sent: "
              f"Keys={self.stats['keypresses']}, "
              f"Clicks={self.stats['mouse_clicks']}, "
              f"Distance={distance_feet:.0f}ft, "
              f"Scrolls={self.stats['mouse_scrolls']}")

        # Reset stats after sending
        self.reset_stats()
        self.last_heartbeat = time.time()

    def process_event(self, event):
        """Process a single input event"""
        # Keyboard events
        if event.type == ecodes.EV_KEY:
            # Only count key presses (value 1), not releases (value 0)
            if event.value == 1:
                # Mouse buttons are also EV_KEY events
                if event.code in [ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE]:
                    self.stats["mouse_clicks"] += 1
                else:
                    # Actual keyboard key
                    self.stats["keypresses"] += 1

        # Mouse movement
        elif event.type == ecodes.EV_REL:
            if event.code == ecodes.REL_X:
                self.stats["mouse_distance_px"] += abs(event.value)
            elif event.code == ecodes.REL_Y:
                self.stats["mouse_distance_px"] += abs(event.value)
            elif event.code in [ecodes.REL_WHEEL, ecodes.REL_HWHEEL]:
                self.stats["mouse_scrolls"] += abs(event.value)

    def run(self):
        """Main event loop"""
        print("\nTracking started! Stats will be sent to ActivityWatch every 60 seconds.")
        print("Press Ctrl+C to stop.\n")

        all_devices = self.keyboard_devices + self.mouse_devices
        devices_dict = {dev.fd: dev for dev in all_devices}

        try:
            while True:
                # Use select to wait for events from any device
                import select
                r, w, x = select.select(devices_dict.keys(), [], [], 1.0)

                for fd in r:
                    device = devices_dict[fd]
                    for event in device.read():
                        self.process_event(event)

                # Send heartbeat if interval elapsed
                if time.time() - self.last_heartbeat >= self.heartbeat_interval:
                    self.send_heartbeat()

        except KeyboardInterrupt:
            print("\n\nShutting down...")
            # Send final stats
            self.send_heartbeat()
            print("Goodbye!")


def main():
    """Main entry point"""
    print("ActivityWatch Input Tracker")
    print("=" * 50)

    tracker = InputTracker()
    tracker.run()


if __name__ == "__main__":
    main()

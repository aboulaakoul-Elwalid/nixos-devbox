#!/usr/bin/env python3
"""
ActivityWatch to Obsidian Vault Daily Logger
Queries ActivityWatch API and updates daily vault files with stats
"""

import json
from urllib.parse import urlencode
from urllib.request import urlopen, Request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from collections import defaultdict
import sys

# Configuration
VAULT_PATH = Path.home() / "Documents" / "vault_elwalid" / "daily"
AW_SERVER = "http://localhost:5600"
HOSTNAME = "omarchy"

def seconds_to_hm(seconds):
    """Convert seconds to hours and minutes format"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    if hours > 0:
        return f"{hours}h {minutes:02d}m"
    else:
        return f"{minutes}m"

def get_buckets():
    """Get all available buckets from ActivityWatch"""
    try:
        req = Request(f"{AW_SERVER}/api/0/buckets")
        with urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception as e:
        print(f"Error getting buckets: {e}")
        return {}

def get_events(bucket_id, start_date, end_date):
    """Get events from a specific bucket for a date range"""
    try:
        # ActivityWatch API expects RFC3339 timestamps with timezone.
        start_utc = start_date.replace(tzinfo=timezone.utc)
        end_utc = end_date.replace(tzinfo=timezone.utc)
        params = {
            "start": start_utc.isoformat().replace("+00:00", "Z"),
            "end": end_utc.isoformat().replace("+00:00", "Z"),
        }
        query = urlencode(params)
        req = Request(f"{AW_SERVER}/api/0/buckets/{bucket_id}/events?{query}")
        with urlopen(req, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception as e:
        print(f"Error getting events from {bucket_id}: {e}")
        return []

def calculate_total_duration(events):
    """Calculate total duration from events in seconds"""
    total = 0
    for event in events:
        total += event.get("duration", 0)
    return total

def aggregate_by_field(events, field):
    """Aggregate events by a specific field (like 'app' or 'language')"""
    aggregated = defaultdict(float)
    for event in events:
        data = event.get("data", {})
        value = data.get(field, "Unknown")
        duration = event.get("duration", 0)
        aggregated[value] += duration
    return dict(aggregated)

def extract_project_from_file(file_path):
    """Extract project name from file path"""
    if not file_path:
        return "unknown"

    path = Path(file_path)
    parts = path.parts

    # Common project indicators
    if 'projects' in parts:
        idx = parts.index('projects')
        if idx + 1 < len(parts):
            return parts[idx + 1]

    if '.config' in parts:
        idx = parts.index('.config')
        if idx + 1 < len(parts):
            return f"config/{parts[idx + 1]}"

    if 'Documents' in parts and 'vault' in parts:
        return "vault"

    # Return directory name if in home subdir
    if len(parts) >= 3:
        return parts[2]

    return "unknown"

def get_daily_stats(target_date):
    """Get all stats for a specific date"""
    start_date = datetime.combine(target_date, datetime.min.time())
    end_date = start_date + timedelta(days=1)

    stats = {
        "date": target_date.strftime("%Y-%m-%d"),
        "total_active": 0,
        "afk_time": 0,
        "coding_time": 0,
        "editors": {},
        "languages": {},
        "projects": defaultdict(float),
        "files": [],
        "apps": {},
        "top_websites": [],
        "input": {
            "keypresses": 0,
            "mouse_clicks": 0,
            "mouse_distance_ft": 0,
            "mouse_scrolls": 0
        }
    }

    buckets = get_buckets()

    # Process each bucket
    for bucket_id, bucket_info in buckets.items():
        bucket_type = bucket_info.get("type", "")
        events = get_events(bucket_id, start_date, end_date)

        if not events:
            continue

        # AFK status
        if bucket_type == "afkstatus":
            for event in events:
                duration = event.get("duration", 0)
                status = event.get("data", {}).get("status", "")
                if status == "not-afk":
                    stats["total_active"] += duration
                else:
                    stats["afk_time"] += duration

        # Window tracking (apps)
        elif bucket_type == "currentwindow":
            apps = aggregate_by_field(events, "app")
            # Filter out unknown and zero duration
            stats["apps"] = {k: v for k, v in apps.items() if k != "unknown" and v > 0}

        # Vim/Neovim tracking
        elif "vim" in bucket_id.lower():
            duration = calculate_total_duration(events)
            stats["coding_time"] += duration
            stats["editors"]["Neovim"] = stats["editors"].get("Neovim", 0) + duration

            # Aggregate by language/file type
            languages = aggregate_by_field(events, "language")
            for lang, dur in languages.items():
                if lang and lang != "Unknown":
                    stats["languages"][lang] = stats["languages"].get(lang, 0) + dur

            # Track projects
            for event in events:
                file_path = event.get("data", {}).get("file", "")
                project = extract_project_from_file(file_path)
                stats["projects"][project] += event.get("duration", 0)

        # Zed tracking
        elif "zed" in bucket_id.lower():
            duration = calculate_total_duration(events)
            stats["coding_time"] += duration
            stats["editors"]["Zed"] = stats["editors"].get("Zed", 0) + duration

            # Aggregate by language
            languages = aggregate_by_field(events, "language")
            for lang, dur in languages.items():
                if lang and lang != "Unknown":
                    stats["languages"][lang] = stats["languages"].get(lang, 0) + dur

            # Track projects
            for event in events:
                file_path = event.get("data", {}).get("file", "")
                project = extract_project_from_file(file_path)
                stats["projects"][project] += event.get("duration", 0)

        # VSCode tracking (if needed in future)
        elif "vscode" in bucket_id.lower():
            duration = calculate_total_duration(events)
            stats["coding_time"] += duration
            stats["editors"]["VSCode"] = stats["editors"].get("VSCode", 0) + duration

            languages = aggregate_by_field(events, "language")
            for lang, dur in languages.items():
                if lang and lang != "Unknown":
                    stats["languages"][lang] = stats["languages"].get(lang, 0) + dur

        # Browser tracking
        elif bucket_type == "web.tab.current":
            # Could process websites here if needed
            pass

        # Input tracking (keyboard/mouse)
        elif bucket_type == "inputstats":
            for event in events:
                data = event.get("data", {})
                stats["input"]["keypresses"] += data.get("keypresses", 0)
                stats["input"]["mouse_clicks"] += data.get("mouse_clicks", 0)
                stats["input"]["mouse_distance_ft"] += data.get("mouse_distance_ft", 0)
                stats["input"]["mouse_scrolls"] += data.get("mouse_scrolls", 0)

    return stats

def replace_section(content, heading, section):
    lines = content.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith(heading):
            start = i
            break

    if start is None:
        content = content.rstrip()
        return f"{content}\n\n{section.rstrip()}\n" if content else f"{section.rstrip()}\n"

    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].startswith("## "):
            end = i
            break

    tail = lines[end:]
    spacer = [""] if tail and tail[0].strip() else []
    updated = lines[:start] + section.rstrip().splitlines() + spacer + tail
    return "\n".join(updated).rstrip() + "\n"

def create_daily_file(target_date, stats):
    """Create or update the daily vault file with stats"""
    date_str = target_date.strftime("%Y-%m-%d")
    file_path = VAULT_PATH / f"{date_str}.md"

    # Check if file exists
    if file_path.exists():
        # File exists - we'll append/update stats section
        with open(file_path, 'r') as f:
            content = f.read()

        content = replace_section(content, "## Daily Stats", format_stats_section(stats))
    else:
        # Create new file from template
        content = f"""---
date: "{date_str}"
tags:
  - Daily
mood:
energy:
focus:
updated: {datetime.now().strftime("%Y-%m-%dT%H:%M:%S.000+01:00")}
edited_seconds: 0
---

{format_stats_section(stats)}

"""

    # Write to file
    VAULT_PATH.mkdir(parents=True, exist_ok=True)
    with open(file_path, 'w') as f:
        f.write(content)

    return file_path

def format_stats_section(stats):
    """Format the stats section as markdown"""
    output = f"## Daily Stats ({stats['date']})\n\n"

    # Main stats line
    if stats["total_active"] > 0:
        output += f"**Active Time**: {seconds_to_hm(stats['total_active'])}"

    if stats["coding_time"] > 60:  # Only show if > 1 minute
        if stats["total_active"] > 0:
            output += "  |  "
        output += f"**Coding Time**: {seconds_to_hm(stats['coding_time'])}"

    output += "\n\n"

    # Coding Stats section (only if there's meaningful coding time)
    if stats["coding_time"] > 60:  # More than 1 minute
        output += "### Coding Stats\n"

        # Main editor
        if stats["editors"]:
            main_editor = max(stats["editors"].items(), key=lambda x: x[1])
            output += f"**Main Editor**: {main_editor[0]} ({seconds_to_hm(main_editor[1])})\n"

            # If multiple editors, show others
            if len(stats["editors"]) > 1:
                other_editors = [f"{k} ({seconds_to_hm(v)})"
                               for k, v in stats["editors"].items()
                               if k != main_editor[0] and v > 60]
                if other_editors:
                    output += f"**Other Editors**: {', '.join(other_editors)}\n"

        # Main project
        if stats["projects"]:
            main_project = max(stats["projects"].items(), key=lambda x: x[1])
            if main_project[0] != "unknown" and main_project[1] > 60:  # More than 1 minute
                output += f"**Main Project**: {main_project[0]}\n"

        output += "\n"

        # Language breakdown
        if stats["languages"]:
            output += "**Language Breakdown**:\n"
            total_coding = stats["coding_time"]
            sorted_langs = sorted(stats["languages"].items(), key=lambda x: x[1], reverse=True)

            # Only show languages with > 1 minute
            meaningful_langs = [(lang, dur) for lang, dur in sorted_langs if dur > 60]

            if meaningful_langs:
                for lang, duration in meaningful_langs:
                    percentage = (duration / total_coding * 100) if total_coding > 0 else 0
                    output += f"- {lang}: {seconds_to_hm(duration)} ({percentage:.1f}%)\n"
                output += "\n"

    # Top applications
    if stats["apps"]:
        output += "### Top Applications\n"
        # Filter and sort apps
        filtered_apps = {k: v for k, v in stats["apps"].items()
                        if v > 60 and k != "unknown"}  # More than 1 minute
        sorted_apps = sorted(filtered_apps.items(), key=lambda x: x[1], reverse=True)[:10]

        for i, (app, duration) in enumerate(sorted_apps, 1):
            # Clean up app names
            clean_name = app.replace("com.mitchellh.", "").replace("dev.zed.", "")
            clean_name = clean_name.replace("brave-browser", "Brave")
            clean_name = clean_name.replace("obsidian", "Obsidian")
            output += f"{i}. {clean_name} - {seconds_to_hm(duration)}\n"
        output += "\n"

    # Activity Stats
    if stats["total_active"] > 0 or stats["afk_time"] > 0:
        output += "### Activity Stats\n"
        output += f"- **Active**: {seconds_to_hm(stats['total_active'])}\n"
        output += f"- **Away**: {seconds_to_hm(stats['afk_time'])}\n"
        output += "\n"

    # Input Stats (keyboard/mouse)
    if stats["input"]["keypresses"] > 0 or stats["input"]["mouse_clicks"] > 0:
        output += "### Input Stats\n"
        if stats["input"]["keypresses"] > 0:
            output += f"- **Keypresses**: {stats['input']['keypresses']:,}\n"
        if stats["input"]["mouse_clicks"] > 0:
            output += f"- **Mouse Clicks**: {stats['input']['mouse_clicks']:,}\n"
        if stats["input"]["mouse_distance_ft"] > 0:
            distance_ft = int(stats["input"]["mouse_distance_ft"])
            distance_mi = distance_ft / 5280
            if distance_mi >= 0.1:
                output += f"- **Mouse Distance**: {distance_ft:,} ft ({distance_mi:.2f} mi)\n"
            else:
                output += f"- **Mouse Distance**: {distance_ft:,} ft\n"
        if stats["input"]["mouse_scrolls"] > 0:
            output += f"- **Mouse Scrolls**: {stats['input']['mouse_scrolls']:,}\n"
        output += "\n"

    return output

def main():
    """Main function"""
    # Check if date argument provided (for manual trigger)
    if len(sys.argv) > 1:
        if sys.argv[1] == "today":
            target_date = datetime.now().date()
        elif sys.argv[1] == "yesterday":
            target_date = (datetime.now() - timedelta(days=1)).date()
        else:
            try:
                target_date = datetime.strptime(sys.argv[1], "%Y-%m-%d").date()
            except ValueError:
                print("Usage: aw-to-vault.py [today|yesterday|YYYY-MM-DD]")
                sys.exit(1)
    else:
        # Default: yesterday (for boot-time run)
        target_date = (datetime.now() - timedelta(days=1)).date()

    print(f"Collecting stats for {target_date}...")

    # Get stats
    stats = get_daily_stats(target_date)

    # Create/update vault file
    file_path = create_daily_file(target_date, stats)

    print(f"✓ Stats written to: {file_path}")
    print(f"  Active time: {seconds_to_hm(stats['total_active'])}")
    if stats['coding_time'] > 0:
        print(f"  Coding time: {seconds_to_hm(stats['coding_time'])}")

if __name__ == "__main__":
    main()

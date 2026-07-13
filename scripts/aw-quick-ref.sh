#!/bin/bash
# ActivityWatch Quick Reference

cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║          ActivityWatch - Quick Reference                       ║
╚════════════════════════════════════════════════════════════════╝

📊 SAVE STATS TO VAULT
  Super+S                    Save today's stats instantly
  aw-to-vault.py today       Same as above
  aw-to-vault.py yesterday   Save yesterday's stats

📈 VIEW STATS
  Web UI:     http://localhost:5600
  Today:      bat ~/Documents/vault_elwalid/daily/$(date +%Y-%m-%d).md
  Yesterday:  bat ~/Documents/vault_elwalid/daily/$(date -d yesterday +%Y-%m-%d).md

🔧 SERVICES
  Status:     systemctl --user status aw-server aw-awatcher
  Restart:    systemctl --user restart aw-server aw-awatcher
  Logs:       journalctl --user -u aw-awatcher -f

🖱️  INPUT TRACKING (Optional)
  Setup:      ~/.local/bin/setup-input-tracking.sh
  Start:      systemctl --user start aw-input-tracker
  Status:     systemctl --user status aw-input-tracker

🔍 DEBUG
  Buckets:    curl -s http://localhost:5600/api/0/buckets/ | jq keys
  Events:     curl -s http://localhost:5600/api/0/buckets/aw-watcher-window_omarchy/events?limit=5 | jq

📁 FILES
  Main Script:  ~/.local/bin/aw-to-vault.py
  Vault Files:  ~/Documents/vault_elwalid/daily/
  Full Docs:    ~/Documents/activitywatch-setup-complete.md

══════════════════════════════════════════════════════════════════
EOF

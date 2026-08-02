#!/usr/bin/env bash
set -euo pipefail

ROOT=/home/elwalid/.local/share/opencode/snapshot

# Kill any snapshot git add that targets /home/elwalid (very heavy)
pgrep -f 'git .*\/home\/elwalid\/\.local\/share\/opencode\/snapshot/.* --work-tree /home/elwalid add .' | xargs -r kill -TERM 2>/dev/null || true

# Ensure all snapshot repos ignore everything by default
if [ -d "$ROOT" ]; then
  for repo in "$ROOT"/*; do
    [ -d "$repo" ] || continue
    mkdir -p "$repo/info"
    cat > "$repo/info/exclude" <<'EOF'
# Ignore everything to prevent heavy home indexing
*
EOF
  done
fi

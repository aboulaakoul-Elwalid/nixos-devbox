#!/usr/bin/env bash
# Deploy (or drift-check) the patched computer-use skill files.
#
# The live skills live in ~/.agents/skills/, which is NOT a git repo. This
# repository holds the authoritative copies. To avoid two silently-diverging
# sources of truth, this script can always answer "are they in sync?".
#
#   ./install.sh check     # diff repo vs deployed (default; exits 1 on drift)
#   ./install.sh deploy    # copy repo -> ~/.agents (backs up what it replaces)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="${AGENT_SKILLS_DIR:-$HOME/.agents/skills}"
MODE="${1:-check}"

FILES=(
  "hyprland-computer-use/bin/hcu-type"
  "hyprland-computer-use/SKILL.md"
  "hassoub/SKILL.md"
  "hassoub/bin/verify"
)

# ~/.agents/skills is the canonical store; Claude Code and Codex read their own
# roots, which on this machine are populated by SYMLINKS back into it (and
# OpenCode shares the same arrangement). So one skill installed here becomes
# native to all three — but only if the symlink exists, which is what this does.
LINK_ROOTS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
)

drift=0
for rel in "${FILES[@]}"; do
  src="$HERE/skills/$rel"
  dst="$DEST/$rel"
  if [ ! -f "$src" ]; then
    echo "MISSING IN REPO  $rel"; drift=1; continue
  fi
  if [ ! -f "$dst" ]; then
    echo "NOT DEPLOYED     $rel"; drift=1
    [ "$MODE" = deploy ] && { mkdir -p "$(dirname "$dst")"; cp -a "$src" "$dst"; echo "  installed"; }
    continue
  fi
  if cmp -s "$src" "$dst"; then
    echo "in sync          $rel"
  else
    echo "DRIFT            $rel"; drift=1
    if [ "$MODE" = deploy ]; then
      cp -a "$dst" "$dst.bak-$(date +%Y%m%d-%H%M%S)"
      cp -a "$src" "$dst"
      echo "  deployed (previous copy backed up)"
    else
      diff -u "$dst" "$src" | head -40
    fi
  fi
done

# A skill that exists in ~/.agents but is not linked into an agent's own root is
# invisible to that agent — installed and useless. Check it explicitly.
for skill in hyprland-computer-use hassoub; do
  for root in "${LINK_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    link="$root/$skill"
    if [ -e "$link" ]; then
      printf 'linked           %s\n' "${root/#$HOME/~}/$skill"
    else
      printf 'NOT LINKED       %s\n' "${root/#$HOME/~}/$skill"; drift=1
      if [ "$MODE" = deploy ]; then
        ln -s "$DEST/$skill" "$link" && echo "  linked"
      fi
    fi
  done
done

if [ "$MODE" = deploy ]; then
  echo "deploy complete"
  exit 0
fi
[ "$drift" -ne 0 ] && { echo; echo "drift detected — run './install.sh deploy' to sync"; exit 1; }
echo "all files in sync"

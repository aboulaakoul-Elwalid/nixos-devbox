---
name: deslop
description: Remove AI-generated code slop from current changes while preserving the real feature/fix.
---

## Goal
Remove "AI slop" patterns (things humans usually would not write) from the current worktree changes.

## How To Run
1. Inspect changes with:
   - `git status`
   - `git diff`
   - `git diff --cached`
2. For each file with slop:
   - Open the file and match existing style
   - Apply minimal edits to remove slop

## Slop Patterns To Remove
- Unnecessary comments that restate code
- Over-defensive checks that add noise (when callers already enforce invariants)
- Single-use variables that should be inlined
- Redundant try/catch that rethrows unchanged
- Style inconsistency vs the surrounding codebase
- Verbose logging that adds no signal

## Rules
- Preserve the actual feature/fix.
- Keep diffs minimal.
- Do NOT run: `git add`, `git commit`, `git push`.

## Output
Finish with a short summary:
- What you removed (counts + categories)
- Files touched
- Any remaining questionable areas to review

---
name: pr-gates
description: Generate PR_GATES.md acceptance gates tailored to the repo stack.
---
## What I do
- Create `PR_GATES.md` at the repo root.
- Tailor gates to the project stack (node/python/rust/etc.).

## When to use me
Use at the start of a project or before letting a worker agent implement changes.

## Output rules
- Include required gates (lint/typecheck/tests) and repo-specific commands.
- If commands are unknown, search the repo for existing scripts and docs before guessing.

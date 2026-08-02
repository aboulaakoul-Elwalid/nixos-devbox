---
name: verification-loop
description: Structure serious research work around specs, gates, slices, receipts, and failure taxonomy.
---

## What I do
- Turn a vague research or eval task into a verification-first loop.
- Standardize the artifact set for serious work:
  - claim / question
  - oracle / invariant
  - metric and slices
  - baseline / candidate
  - acceptance gates
  - failure taxonomy
  - replay receipt
  - decision

## When to use me
Use this skill when the task is primarily about:
- evals or benchmarks
- baseline vs candidate comparisons
- experiment reports
- failure analysis
- reproducibility / replay receipts
- audit workflows
- any serious research task where “good explanation” is not enough

## Default artifact targets
- `docs/spec.md`
- `docs/gates.md`
- `docs/research.md`
- `docs/QUESTIONS.md`
- `docs/walid_runs/`

If the repo does not have these, create the smallest useful subset instead of leaving only chat output.

## Required loop
For substantial work, make these explicit:
1. claim / question
2. oracle / invariant
3. metric
4. slices
5. baseline
6. candidate
7. gates
8. failure taxonomy
9. replay receipt
10. decision

## Gate contract
Every serious gate should answer:
- what is being checked?
- what command or procedure runs it?
- what is the pass/fail rule?
- what artifact path records the result?

Use the bundled template:
- `~/.config/opencode/skill/verification-loop/gates-template.md`

## Failure taxonomy contract
Every serious failure taxonomy should capture:
- failure class
- trigger / slice
- observed behavior
- expected behavior
- likely cause
- confidence
- next check

Use the bundled template:
- `~/.config/opencode/skill/verification-loop/failure-taxonomy-template.md`

## Replay receipt contract
Every serious run receipt should capture:
- timestamp / run id
- claim
- oracle
- metric
- slices
- baseline
- candidate
- commands or procedures
- result summary
- artifact paths
- decision
- next action

Use the bundled template:
- `~/.config/opencode/skill/verification-loop/receipt-template.md`

## Output rules
- Prefer the smallest artifact set that still makes the work auditable.
- Do not generate prose-only summaries when the task is really an experiment/eval/failure-analysis loop.
- Favor text-first, git-friendly formats.
- Keep schemas lightweight and readable in markdown.

## Relationship to other skills
- Pair with `learning` when the task also needs strong explanation or a browser-rendered teaching artifact.
- Pair with `pr-gates` when the repo needs PR acceptance gates.
- Pair with `handoff-template` when pausing or transferring ongoing research work.

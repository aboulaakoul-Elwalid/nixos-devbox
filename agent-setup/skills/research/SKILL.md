---
name: "research"
description: "Research, compare, audit, investigate, or de-risk unclear work before implementation, separating local repo facts from external documentation."
---

# Research Skill

## Purpose

Turn unclear work into an evidence-backed recommendation or executable plan before editing.

Research is a workflow, not a separate model lane. Use native `plan` for strategy and native `build` only when the user asks to implement.

## When To Use

- codebase understanding before a change
- comparing implementation approaches
- choosing between libraries, models, APIs, or architectures
- de-risking a migration, refactor, deployment, or experiment
- turning a vague idea into a concrete artifact, gate, metric, or decision
- diagnosing a bug when the root cause is not obvious

## Default Rules

- Understand first; do not edit by default.
- Separate repo facts from external doc facts.
- Use `general` for multi-file or open-ended repo investigation.
- Use `librarian` for external APIs, unfamiliar frameworks, unclear errors, and version-sensitive behavior.
- Delegate proactively once the need is obvious, but keep synthesis in the main agent.
- Surface assumptions, tradeoffs, risks, and confidence explicitly.
- End with a recommendation and the next artifact to create or change.

## Output Shape

For non-trivial research, produce:

- goal / question
- constraints
- repo facts
- doc facts
- options considered
- recommendation
- risks / unknowns
- next artifact
- verification step

For serious eval, benchmark, reproduction, or failure-analysis work, also include:

- claim / question
- oracle / invariant
- metric and slices
- baseline vs candidate
- acceptance gates
- failure taxonomy
- replay receipt

Use the `verification-loop` skill for that heavier loop instead of duplicating its templates here.

## Artifact Targets

Prefer durable repo-local artifacts when they will help future sessions:

- `docs/research.md`
- `docs/spec.md`
- `docs/gates.md`
- `docs/QUESTIONS.md`
- `docs/walid_runs/`

If the repo has no docs structure, create only the smallest useful artifact. Do not create documentation sprawl for a simple answer.

## Relationship To Other Skills

- Pair with `verification-loop` for specs, gates, slices, receipts, and failure taxonomy.
- Pair with `learning` when the task needs a teaching artifact or deeper explanation.
- Pair with `learning` plus `codex_imagegen` when research synthesis should become a polished article with generated editorial imagery; keep evidence figures deterministic and data-backed.
- Pair with `local-first-compute` before GPU, training, inference, rendering, or long-running jobs.
- Pair with `handoff-template` when research is paused or handed off.

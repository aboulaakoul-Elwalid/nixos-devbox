# OpenCode Setup Guide

> WALID bootstrap and runbook. Keep this practical.

## Quick Reference

| Command | Description |
|---------|-------------|
| `oc` | Launch OpenCode through the local wrapper |
| `oc-walk "task"` | Run unattended with away rules |
| `oc-night "task"` | Run long unattended work |
| `/interactive` | Pair-programming mode with learning on |
| `/away` | No-question mode for short unattended work |
| `/night` | More aggressive unattended mode |
| `/plan "task"` | Plan before building |
| `Tab` | Switch between plan and build |
| `/council "question"` | Ask the WALID 4-oracle council (GPT lane + Opus + Gemini + Grok) |
| `/review` | Judge + Codex review gate |
| `/handoff` | Capture a clean session handoff with verify/rollback notes |
| `/machine "task"` | Apply local-first compute routing |
| `/modal` | Modal GPU lane |
| `/kaggle` | Kaggle GPU/TPU lane |
| `/bootstrap` | Create WALID workflow files in a repo |

## Install Strategy

Fast-moving AI CLIs are npm-managed on this machine:

- `opencode` -> `~/.npm-global/bin/opencode`
- `~/.local/bin/opencode` -> NixOS-friendly wrapper entrypoint
- `codex` -> `~/.npm-global/bin/codex`

NixOS provides the surrounding system packages, shell environment, and machine configuration.

## Core Runtime Files

| Path | Purpose |
|------|---------|
| `~/.config/opencode/opencode.json` | Main runtime config |
| `~/.config/opencode/opencode.away.json` | Away/night overrides |
| `~/.config/opencode/oh-my-opencode.json` | Agent model overrides |
| `~/.config/opencode/AGENTS.md` | Policy spine |
| `~/.config/opencode/MACHINE.md` | Hardware and local capacity |
| `~/.config/opencode/USER.md` | Durable user preferences |
| `~/.config/opencode/command/` | WALID-specific slash commands |
| `~/.config/opencode/skill/` | Durable skills |

## Minimal Model Setup

Keep the active stack small:

- `openai/gpt-5.6-sol` -> GPT oracle, proof-style synthesis, planning, architecture, deep review
- `openai/gpt-5.6-terra` / `openai/gpt-5.6-terra-pro` -> implementation, debugging, verification workers
- `openai/gpt-5.4` -> fallback GPT oracle when newer models are unavailable
- `openai/gpt-5.3-codex` / `openai/gpt-5.3-codex-high` -> Codex review and deep work
- Copilot Opus -> oracle perspective
- `github-copilot/gpt-5-mini` -> explore/librarian

Use `/models` and the JSON configs as source of truth instead of maintaining long model tables by hand.

## Native Modes In WALID

### Built-in

- `build`
- `plan`

Research and learning are no longer native modes. Keep them as durable skills (`research`, `learning`, `verification-loop`) instead of extra model lanes.

Prefer the native build/plan flow instead of encoding mode behavior into long docs.

## Research Artifact Loop

For serious learning/research tasks, the canonical WALID loop is:

1. question / claim
2. one-page spec
3. oracle / invariant
4. metric and slices
5. baseline
6. candidate
7. acceptance gates
8. failure review
9. replay / archive
10. decision and next artifact

This is the default shape behind the setup. Good explanations are useful, but they should support this loop rather than replace it.

## When To Use What

- `research` skill:
  - investigate a topic or repo
  - separate facts from assumptions
  - define metric/oracle/slice plans
  - decide what artifact should exist next
- `learning` skill:
  - deeply understand a concept, mechanism, or code path
  - produce teaching artifacts, research notes, benchmark reports, or audit sheets
  - preserve intuition, sharpen it, and pressure-test understanding
- `verification-loop` skill:
  - structure serious research work around specs, gates, slices, receipts, and failure taxonomy
  - use when the task is benchmark/eval-heavy or needs reproducible decisions
- `bootstrap`:
  - materialize repo-local workflow files when they are missing
  - especially `docs/spec.md`, `docs/gates.md`, `docs/research.md`, `docs/QUESTIONS.md`

Typical high-signal examples:
- benchmark / eval harness design with slice-aware gates
- Morocco-specific applied AI system with deterministic validators
- research-paper reproduction with baseline/candidate comparison and failure taxonomy

## High-Value Commands

Keep only commands that add real WALID value:

- `/council`
- `/deploy`
- `/review`
- `/handoff`
- `/machine`
- `/bootstrap`
- `/task`
- `/swarm`
- `/sandbox`
- `/modal`
- `/kaggle`

Avoid adding commands that merely duplicate `/models`, `/connect`, mode switching, or basic git usage.

`/council` in WALID is the direct oracle workflow: `oracle-gpt` + `oracle-opus` + `oracle-gemini` + `oracle-grok`, then synthesis. It should not fall back to the generic `council` skill. Codex/Claude use the shared `~/.agents/skills/council` skill, which also fans out to Grok via `opencode run -m xai/grok-4.5`.

## Skills To Invest In

- `droplet-deploy`
- `nixos-desktop`
- `research`
- `learning`
- `verification-loop`
- `local-first-compute`
- `handoff-template`
- `pr-gates`
- `ralph-bootstrap`

Keep skills for durable domain knowledge and repeatable workflows. Prefer them over plugins when possible.

## Local-First Compute

Default routing:

- Local CPU first for coding, tests, indexing, docs, and most research
- Local GPU first for moderate jobs that fit the RTX 3060 12 GiB envelope
- Modal/Kaggle only when local limits are exceeded or remote scale is clearly better

Use `/machine` or the `local-first-compute` skill before defaulting to cloud GPUs.

## Review And Handoff

- Run `/review` before commits.
- Use `HANDOFF.md` for substantial work, away/night work, or interrupted sessions.
- Keep acceptance gates explicit in `docs/gates.md` or `PR_GATES.md` when possible.

### What `/handoff` does

It creates or refreshes `HANDOFF.md` with the state another future session needs:

- goal and non-goals
- constraints
- files touched and why
- acceptance gates and how to verify
- rollback plan
- open questions and risks

Use it when:

- pausing mid-task
- finishing away/night work
- handing off between sessions
- leaving behind work you may want to resume later

## WALID Workflow Files

Preferred repo-local state:

- `docs/research.md`
- `docs/spec.md`
- `docs/gates.md`
- `docs/QUESTIONS.md`
- `docs/sessions/`
- `docs/walid_tasks/`
- `docs/walid_runs/`

Use `/bootstrap` when these are missing.

Good default artifact set for a serious repo:

- `docs/spec.md`
- `docs/gates.md`
- `docs/research.md`
- `docs/QUESTIONS.md`
- replay/eval receipts under `docs/sessions/` or `docs/walid_runs/`

## Update And Maintenance

Typical flow:

```bash
oc-update
oc-test
```

Current behavior:

- `oc-update` wraps the active npm-managed `opencode` install
- `opencode upgrade --method npm` is the native upgrade path when you want to run it directly
- `codex` updates through npm as well

Useful checks:

```bash
opencode --version
opencode models openai
npm list -g --depth=0 opencode-ai @openai/codex
```

## Troubleshooting

### Wrong mode

- Use `Tab` for build/plan.
- Use `/interactive`, `/away`, or `/night` for availability behavior.

### Push blocked locally

- This is intentional. Review locally and push manually.

### Auth drift

- If provider auth behaves strangely, re-check plugin/auth setup first.

### Update drift

- If `opencode models openai` or runtime behavior looks stale, verify the npm version and restart the session.

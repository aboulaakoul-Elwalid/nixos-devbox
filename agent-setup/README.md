# Agent Setup

A portable, secrets-scrubbed snapshot of Elwalid's AI coding-agent configuration:
Claude Code, OpenCode, and Codex CLI policy files, plus his library of custom
Claude/Codex/OpenCode "skills" (durable domain knowledge and repeatable
workflows). This is here so a friend can reproduce *how he works with AI
agents* — the working style, the review discipline, the skill library —
without inheriting any of his personal accounts, credentials, or
project-specific data.

## What's in here

```
agent-setup/
├── claude-code/
│   ├── CLAUDE.md          # global Claude Code policy ("WALID Claude Code")
│   └── agents/            # 5 custom Claude Code subagent definitions
├── codex/
│   └── AGENTS.md          # global Codex CLI policy ("WALID Codex")
├── opencode/
│   ├── AGENTS.md          # global OpenCode policy spine
│   ├── SETUP.md           # OpenCode bootstrap/runbook
│   ├── USER.md            # durable user/working-style preferences
│   └── soul.md             # communication-style rules
└── skills/                # 50 shared Claude/Codex/OpenCode skills
```

## How to use it

### Claude Code

1. Install Claude Code normally (see Anthropic's docs).
2. Copy `agent-setup/claude-code/CLAUDE.md` to `~/.claude/CLAUDE.md`.
3. Copy `agent-setup/claude-code/agents/*.md` to `~/.claude/agents/`.

### Skills

`agent-setup/skills/` holds each skill as its own directory (`SKILL.md` plus
any bundled scripts/templates/references it ships with). On the source
machine these live in `~/.agents/skills/` and get symlinked into
`~/.claude/skills/<name>` so Claude Code, Codex, and OpenCode can all see the
same skill library. To reproduce that:

- Copy `agent-setup/skills/*` to `~/.agents/skills/` (or wherever you want to
  keep them), then symlink each one into `~/.claude/skills/<name>` —
  `ln -s ~/.agents/skills/<name> ~/.claude/skills/<name>` — matching how the
  source machine does it.
- OR, simpler: just copy them directly into `~/.claude/skills/<name>` if you
  don't want the indirection layer.

### OpenCode

1. Install the OpenCode CLI yourself.
2. Drop `agent-setup/opencode/AGENTS.md`, `SETUP.md`, `USER.md`, and `soul.md`
   into `~/.config/opencode/`.

### Codex

1. Install the Codex CLI yourself.
2. Drop `agent-setup/codex/AGENTS.md` into wherever your Codex install expects
   it (commonly `~/.codex/AGENTS.md`).

## What's deliberately NOT included

No accounts, API keys, MCP server tokens, or provider configs are included
anywhere in this directory. Each of these tools needs its own fresh
`auth`/login step on your machine, and you'll need to configure your own
model/provider settings. Specifically left out:

- `~/.claude/.credentials.json`, `~/.claude/mcp.json`, `~/.claude/settings.json`,
  `~/.claude/settings.local.json` — API keys, MCP tokens, local permission grants.
- `~/.claude/projects/` and all session/history/telemetry/sqlite/log files —
  conversation transcripts and usage data, not configuration.
- `~/.config/opencode/opencode.json`, `config.json`, `tui.json`,
  `oh-my-opencode.json` (and their `.bak*` variants) — these mix personal
  project paths, model-provider wiring, and possibly credentials; you should
  build your own provider config from scratch.
- `~/.codex/config.toml` and any Codex session/history/state sqlite files —
  local runtime state, not portable policy.
- Everything under `~/.grok/` (`auth.json`, sessions, etc.) — not part of this
  export at all.

You will need to run each tool's own login/auth flow (`claude`, `opencode
auth login`, `codex login`, etc.) and pick your own models/providers — the
policy files here describe *working style*, not *which account or API key to
use*.

---
name: council
description: Consult four genuinely independent model lanes — host orchestrator, Gemini 3.1 Pro, Claude Opus, and xAI Grok 4.5 — then synthesize one decision with consensus and disagreement analysis. Use only when the user explicitly asks for council, multiple model opinions, Gemini/Opus/Grok takes, or when a consequential ambiguous decision clearly warrants cross-model review.
---

# Model Council

Run a real multi-model council. Do not simulate personas. The host agent (Codex, Claude Code, or OpenCode build) owns the final decision and any implementation.

## Guardrails

- Use council only for consequential ambiguity, not routine coding decisions.
- Keep Gemini, Opus, and Grok read-only. They receive a bounded evidence packet and must not edit files.
- Give every external model the same neutral packet.
- Redact secrets and keep the packet focused and below the consultation size limit.
- Form the host agent's initial recommendation before reading external answers to preserve independence.
- If one lane fails, continue with the others and report the failure.
- Do not equate agreement with correctness; weigh evidence and domain fit.

## Stage 1: Build The Evidence Packet

Include:

1. The precise question or decision.
2. Relevant repository facts discovered by the host agent.
3. Constraints, success gates, and non-goals.
4. Essential snippets, errors, measurements, or diff summaries.
5. This requested response shape:

```text
Recommended option
<answer>

Strongest reasons
<concise bullets>

Risks and tradeoffs
<concise bullets>

Default choice
<one clear choice>
```

Do not seed the packet with the host agent's preferred conclusion.

## Stage 2: Gather Independent Takes

1. Record the host agent's own recommendation privately before inspecting external replies.
2. Prefer the deterministic council wrapper (Gemini + Opus + Grok in parallel):

```bash
printf '%s\n' "$packet" | bash <council-skill-dir>/scripts/council.sh
```

Resolve `<council-skill-dir>` to this skill's directory.

Lane routing inside the wrapper:

| Lane | How it runs |
|------|-------------|
| Gemini 3.1 Pro | sibling `antigravity-consult` (`consult.sh gemini`) |
| Claude Opus | sibling `antigravity-consult` (`consult.sh opus`) |
| xAI Grok 4.5 | `scripts/consult-grok.sh` → `opencode run -m xai/grok-4.5` |

Optional single-lane Grok check:

```bash
printf '%s\n' "$packet" | bash <council-skill-dir>/scripts/consult-grok.sh
```

### OpenCode-native path

When already inside OpenCode, `/council` may instead launch leaf oracle subagents in parallel:

- `oracle-gpt`
- `oracle-opus`
- `oracle-gemini`
- `oracle-grok` (real `xai/grok-4.5`)

That path is equivalent for synthesis; do not also run the bash wrapper in the same turn unless a lane failed.

## Stage 3: Verify And Synthesize

Check external claims against local code, tests, and primary documentation when material. Then return:

### Consensus

What all available lanes agree on.

### Disagreement

Where they differ, why, and which evidence is stronger.

### Decision

The final recommendation in 2-4 bullets.

### Rationale

Which model observations mattered and why. Attribute each lane accurately (host / Gemini / Opus / Grok).

### Tradeoffs

What the decision gives up or leaves uncertain.

### Next Steps

Concrete implementation or verification actions. Continue into implementation when the user's request is actionable; council is not a stopping point.

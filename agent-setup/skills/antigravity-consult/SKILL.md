---
name: antigravity-consult
description: Ask Gemini 3.1 Pro or Claude Opus through the local Antigravity CLI for a read-only independent opinion. Use when the user explicitly requests a Gemini or Opus take, or when a high-impact architecture, debugging, review, or research decision benefits from one external model perspective. Do not use for routine work or let the consultant edit files.
---

# Antigravity Consult

Use Antigravity as a bounded consultant. Codex remains responsible for repository inspection, decisions, edits, and verification.

## Select The Consultant

- Use `gemini` for broad synthesis, multimodal-adjacent reasoning, research framing, or a deliberately different Google-model perspective.
- Use `opus` for architecture critique, nuanced code review, debugging hypotheses, or adversarial reasoning.
- If the user names a model, honor that choice.
- If the user asks for multiple independent opinions, use `$council` instead.

## Prepare The Packet

Send a self-contained, neutral packet containing only what the consultant needs:

1. State the decision or question precisely.
2. Include constraints and success criteria.
3. Include relevant code snippets, errors, test evidence, or a concise diff summary.
4. Ask for a recommendation, strongest reasons, risks, and a default choice.
5. Do not include Codex's preferred answer before the consultant responds.

Before sending, remove credentials, tokens, private keys, `.env` contents, private customer data, and unrelated proprietary material. Prefer focused snippets over whole files. Keep the packet under 50 KiB unless `AGY_CONSULT_MAX_BYTES` is deliberately changed.

State whether the consultant may rely on general model knowledge only or may use external research. Do not ask the consultant to inspect or modify the repository. The wrapper runs from an isolated temporary directory with Antigravity sandbox mode enabled.

## Run

Pipe the packet over stdin:

```bash
printf '%s\n' "$packet" | bash <skill-dir>/scripts/consult.sh gemini
printf '%s\n' "$packet" | bash <skill-dir>/scripts/consult.sh opus
```

Resolve `<skill-dir>` to this skill's directory. Optional timeout examples:

```bash
printf '%s\n' "$packet" | bash <skill-dir>/scripts/consult.sh --timeout 15m opus
```

The wrapper accepts `gemini`, `gemini-high`, `opus`, and `claude`. Current model names can be overridden with `AGY_GEMINI_MODEL` and `AGY_OPUS_MODEL` if Antigravity changes its catalog. It validates the selected name against `agy models` before sending the packet.

## Return The Take

- Clearly attribute the response to the selected Antigravity model.
- Treat it as advisory evidence, not authority.
- Check factual or code claims against local evidence before acting.
- Mention consultant failure or timeout plainly; do not fabricate a take.
- Never expose chain-of-thought or ask the consultant to provide hidden reasoning. Request concise rationale instead.

---
name: cloudflare
description: "Use when working with Cloudflare on Elwalid's machine: Wrangler auth, Workers, Pages, KV, D1, R2, DNS, Access, Tunnel, account verification, deployment, or troubleshooting Cloudflare CLI access without rediscovering local setup."
metadata:
  short-description: Cloudflare local auth and deploy workflow
---

# Cloudflare

Use this skill for Cloudflare account checks, Wrangler-based deployments, Workers, Pages, KV, D1, R2, DNS, Access, or Tunnel work on this machine.

## Local Baseline

- Direct `wrangler` binary is not installed.
- Use `npx --yes wrangler@latest ...` unless a repo provides its own pinned Wrangler.
- Direct `cloudflared` binary is not installed.
- Cloudflare API auth was verified on 2026-06-13 with `CLOUDFLARE_API_TOKEN` from `~/.config/cloudflare/env`.
- `~/.zshrc` sources `~/.config/cloudflare/env`, so new interactive shells should inherit `CLOUDFLARE_API_TOKEN` and `CF_API_TOKEN`.
- `~/.zshenv` also sources `~/.config/cloudflare/env`, so non-interactive `zsh -lc ...` automation should inherit the token.
- `~/.config/cloudflare/env` is the durable local secret file; it must stay outside repos and should be `0600`.
- Do not rediscover tokens from shell history unless the user explicitly asks for token recovery.
- Account name: `<SET-YOUR-OWN-VALUE>` (your Cloudflare account's own name/email).
- Account ID: `<SET-YOUR-OWN-VALUE>`.
- Wrangler version verified: `4.100.0`.
- The durable token is scoped for `<your-domain>` DNS automation. It verifies through the Cloudflare API and can read/write DNS records for your zone.
- `wrangler whoami`, Pages, KV, D1, and R2 may fail with this scoped token because it does not have broad account discovery/resource permissions. Treat that as a permission scope limit, not a broken local token, unless the task specifically needs those products.
- DNS edit for `<your-domain>` was verified by creating a test record on the source machine; treat this line as a template for your own verification, not a real record.

## Safety

- Do not print tokens or read secret-bearing files unless the user explicitly asks.
- Do not read `.env`, `.ssh`, `.gnupg`, or credential files for basic verification.
- For normal Cloudflare work, source `~/.config/cloudflare/env` if needed; do not inspect its value.
- Prefer `wrangler whoami` and resource list calls over inspecting local auth files.
- Mask account IDs and emails in user-facing summaries unless the user needs exact values.

## Fast Verification

Run the bundled script first:

```bash
bash /home/elwalid/.agents/skills/cloudflare/scripts/check-cloudflare.sh
```

If doing it manually:

```bash
source ~/.config/cloudflare/env
npx --yes wrangler@latest --version
curl -fsS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/user/tokens/verify
curl -fsS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=<your-domain>"
```

For broader Wrangler products, probe capability explicitly and do not assume failure means the DNS token is invalid:

```bash
npx --yes wrangler@latest whoami
npx --yes wrangler@latest pages project list
npx --yes wrangler@latest kv namespace list
npx --yes wrangler@latest d1 list
npx --yes wrangler@latest r2 bucket list
```

## Workflow

1. Source `~/.config/cloudflare/env` in non-interactive shells if `CLOUDFLARE_API_TOKEN` is missing.
2. Check for a repo-local Wrangler config first: `wrangler.toml`, `wrangler.json`, or `wrangler.jsonc`.
3. If no local config exists, use explicit command arguments instead of inventing project settings.
4. Verify DNS-token auth with Cloudflare API token verification and a zone lookup for your own domain before DNS work.
5. Use the smallest resource-specific list command needed to prove access.
6. For Tunnel or Cloudflare Access CLI work, first check `command -v cloudflared`; if missing, report that the account is authenticated through Wrangler but `cloudflared` is unavailable locally.
7. For deployments, prefer repo-pinned commands from `package.json` when present; otherwise use `npx --yes wrangler@latest`.

## Known Good Commands

```bash
npx --yes wrangler@latest whoami
npx --yes wrangler@latest pages project list
npx --yes wrangler@latest kv namespace list
npx --yes wrangler@latest d1 list
npx --yes wrangler@latest deploy
npx --yes wrangler@latest pages deploy <directory> --project-name <name>
```

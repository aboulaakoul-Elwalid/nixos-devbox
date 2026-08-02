---
name: codex-security
description: Use Codex Security CLI and bundled skills to scan repositories, review pull-request or working-tree security changes, validate suspected findings, patch vulnerabilities, export SARIF/JSON/CSV evidence, or add Codex Security agent integration. Trigger when the user asks to use codex-security, Codex Security, vulnerability scanning, security scan artifacts, finding validation, security remediation from scan results, or CI setup for Codex Security.
---

# Codex Security

## Operating Posture

Use Codex Security as a security evidence tool, not as a blanket proof of safety. It can find, validate, and help fix vulnerabilities, but a scan result supports only the scanned scope, selected mode, reported coverage, and exact artifact set.

Before running commands:

- Confirm the repository is owned by the user or permitted for assessment.
- Inspect repo policy (`AGENTS.md`, security docs, CI) and define scope: full repo, selected paths, a diff, or the working tree.
- Keep scan output outside the repository unless the user explicitly wants tracked artifacts. Results can include source excerpts and vulnerability detail.
- Never read or print secrets to authenticate. Use an existing sign-in, device auth, or environment variables/secrets provided by the user.
- Treat network/package install/authentication as approval-worthy when the sandbox or local policy requires it.

## Quick Checks

Prefer a read-only capability check before scanning:

```bash
npx codex-security --version
npx codex-security info --json
npx codex-security --help
npx codex-security scan --help
```

The CLI is in beta and requires access. Official prerequisites are Node.js 22+ and Python 3.10+ for scans and exports. If the package is unavailable or access is missing, report that blocker plainly and continue with manual review only if the user accepts the weaker evidence.

## Agent Integration

If the user wants Codex Security available to agents, prefer the official sync command when the CLI is installed:

```bash
npx codex-security skills add
```

The CLI also exposes:

```bash
npx codex-security mcp add
npx codex-security --llms
npx codex-security scan --schema --format json
```

MCP exposes read-only `info` metadata only. Scans, exports, authentication, validation, and patching remain CLI-only, so do not imply that MCP can run scans.

## Scan Workflow

Use the narrowest honest scan that answers the request.

For full or selected-path scans:

```bash
SCAN_DIR="${TMPDIR:-/tmp}/codex-security-results/$(basename "$PWD")"
npx codex-security scan . --output-dir "$SCAN_DIR" --dry-run
npx codex-security scan . --output-dir "$SCAN_DIR"
```

For working-tree review:

```bash
npx codex-security scan . --working-tree --output-dir "$SCAN_DIR"
```

For pull-request or branch comparison:

```bash
npx codex-security scan . --diff "$BASE_REF" --head "$HEAD_REF" --output-dir "$SCAN_DIR"
```

For deeper analysis, use `--mode deep` only when the user accepts the extra time/cost:

```bash
npx codex-security scan . --mode deep --output-dir "$SCAN_DIR"
```

When architecture notes, threat models, or security policies exist, pass them as context:

```bash
npx codex-security scan . \
  --knowledge-base docs/architecture.md \
  --knowledge-base docs/security \
  --output-dir "$SCAN_DIR"
```

## Review Results

Open `report.md` first, then inspect structured artifacts as needed:

- `findings.json`: finding identifiers, severity, confidence, taxonomy, locations, evidence, reachability, and remediation.
- `coverage.json`: reviewed surfaces, exclusions, deferred work, open questions, and coverage completeness.
- `scan-manifest.json`: scan identity, target, scope, status, and artifact records.

Coverage values matter:

- `complete`: selected scope was covered.
- `partial`: deferred work or other limits exist.
- `unknown`: coverage completeness was not determined.

Do not use `partial` or `unknown` coverage as clean security evidence without naming the limit.

## Validate And Patch

Use validation for suspected or remediated findings. A later scan comparison alone does not prove a fix.

```bash
npx codex-security validate findings.json "Possible SQL injection in src/query.ts:42"
npx codex-security patch findings.json "Missing authorization check in src/routes.ts:18"
```

Treat generated patches as proposals. Review the diff, keep the fix minimal, run the repository's normal tests plus any targeted security check, and independently revalidate the finding when possible.

## Export And CI

For machine-readable evidence:

```bash
npx codex-security export "$SCAN_DIR" --export-format sarif --source-root "$PWD" --output "$SCAN_DIR/exports/results.sarif"
npx codex-security export "$SCAN_DIR" --export-format json --output "$SCAN_DIR/exports/findings.json"
npx codex-security export "$SCAN_DIR" --export-format csv --output "$SCAN_DIR/exports/findings.csv"
```

For CI setup, keep credentials in CI secrets, install the approved package outside the repository checkout, run PR/diff scans first in advisory mode, then add `--fail-on-severity` only after reviewing signal quality and runtime. Skip untrusted fork PRs when secrets would be exposed.

## Closeout

Report:

- Scope scanned and command shape, without leaking secrets.
- Scan directory and important artifact paths.
- Finding count and severity breakdown.
- Coverage status and any deferred/open surfaces.
- Fixes applied, validation run, and remaining risk.

Never claim production readiness, compliance, or absence of vulnerabilities from Codex Security alone.

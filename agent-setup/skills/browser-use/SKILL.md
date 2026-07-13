---
name: browser-use
description: "Direct browser control via CDP for exploratory QA, UI automation, scraping, screenshots, and integration diagnosis."
---

# Browser Use

Use the installed `browser-use` harness for real browser control through CDP. It is useful for exploratory product QA as well as deterministic interaction: inspect visible state, exercise a user workflow, capture evidence, and diagnose browser-to-service failures.

## Installed Interface

The current harness uses Python heredocs; it does not use the older `browser-use open/state/click` subcommand examples.

```bash
browser-use --doctor

browser-use <<'PY'
new_tab("http://127.0.0.1:5188/factory-studio")
wait_for_load()
print(page_info())
capture_screenshot("output/browser-use/factory-studio.png")
PY
```

Helpers are pre-imported. Common helpers include:

- `new_tab(url)` - open a new real tab
- `ensure_real_tab()` - move away from an internal or stale tab
- `wait_for_load()` - wait after navigation
- `page_info()` - inspect URL, title, and page state
- `capture_screenshot(path)` - save a visual artifact
- `click_at_xy(x, y)` and keyboard helpers - interact at the rendered surface
- `js(expression)` - inspect or extract DOM state when coordinates are not enough
- `cdp(method, params)` - use a raw CDP call for advanced browser diagnostics

Use screenshots before coordinate clicks and after meaningful interactions. Prefer DOM inspection with `js(...)` when the target has stable semantics; use coordinates when the rendered surface, canvas, iframe, or shadow DOM makes that more reliable.

## Exploratory QA Workflow

1. Define the user goal and the observable success condition.
2. Run `browser-use --doctor`; confirm the local app or service is reachable before blaming the UI.
3. Open the app, wait for load, inspect `page_info()`, and capture a baseline screenshot.
4. Exercise the primary user path, taking a screenshot and recording visible state after each significant transition.
5. Probe meaningful edge states: loading, empty, unavailable, stale, synthetic, live, rejected, and error states.
6. Check responsive behavior at a wide desktop viewport and at least one narrow viewport. Use the viewport interaction reference when needed.
7. Inspect console and network failures. A page that renders can still be broken if API, CORS, WebSocket, auth, or provenance calls fail.
8. Check keyboard reachability, accessible names, focus changes, and whether disabled controls explain why they are unavailable.
9. For industrial/evidence workflows, verify source labels, approval flags, read-only boundaries, and named blockers. Never treat demo or synthetic data as customer-approved or live.
10. Close the browser or remote daemon and remove only artifacts created for the run.

## Evidence And Diagnosis

For each finding, record:

- URL and viewport
- exact action sequence
- expected versus observed behavior
- visible text or state proving the result
- screenshot, console, or network artifact when useful
- whether the cause is UI logic, an unavailable dependency, configuration, or test-environment setup

Do not report a backend dependency as a UI regression without checking the request and response. Do not report a passing screenshot as proof that live data, customer approval, OT write capability, or production readiness exists.

## Local Chrome And CDP

The normal local flow attaches to a running Chrome/Chromium CDP endpoint. If the daemon cannot connect:

```bash
browser-use --doctor
```

For an isolated disposable browser, start system Chromium in a persistent terminal session and point the harness at its DevTools endpoint:

```bash
/run/current-system/sw/bin/chromium \
  --headless=new --no-sandbox --disable-gpu \
  --no-first-run --no-default-browser-check \
  --user-data-dir=/tmp/codex-browser-profile \
  --remote-debugging-port=9222 about:blank
```

In a second terminal:

```bash
BU_CDP_URL=http://127.0.0.1:9222 browser-use <<'PY'
new_tab("http://127.0.0.1:5188/factory-studio")
wait_for_load()
print(page_info())
PY
```

Use a separate profile for disposable sessions. Do not read or export cookies, secrets, or personal browser data unless the user explicitly authorizes it.

## Remote Browsers

Use Browser Use Cloud only when an isolated remote browser or parallel browser is actually needed. Remote daemons bill until stopped.

```bash
browser-use auth login

browser-use <<'PY'
start_remote_daemon("short-session-name")
PY

BU_NAME=short-session-name browser-use <<'PY'
new_tab("https://example.com")
print(page_info())
PY
```

Stop the named daemon when finished:

```bash
BU_NAME=short-session-name browser-use <<'PY'
stop_remote_daemon("short-session-name")
PY
```

Stop at login walls for passwords, MFA, consent, or ambiguous account selection. Existing signed-in SSO may be used only when the account choice is unambiguous.

## Interaction References

For difficult mechanics, read only the relevant reference from the Browser Use harness documentation: network requests, tabs, screenshots, viewport, downloads, dialogs, iframes, shadow DOM, scrolling, or uploads.

Keep task-specific helpers in `$BH_AGENT_WORKSPACE/agent_helpers.py`; do not grow the core harness with one-off application logic.

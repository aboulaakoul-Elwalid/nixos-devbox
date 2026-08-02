---
name: hassoub
description: Use to actually verify an app by driving it — a web app you deployed, a VS Code/VSCodium extension you built, or any GUI flow that ends in a native file dialog. Runs a real browser or editor, exercises the UI, and reports whether a genuine defect was found, distinguishing a real bug from benign noise. Use when asked to test/verify/QA a running app, check whether a change broke the UI, confirm a fix, or reproduce a reported bug. Not for unit tests or static review — this drives the running product.
---

# Hassoub — drive and verify a running app

One command drives the app and reports a verdict. Everything underneath was
measured, and the verdicts come from tools with their own gates — this skill is
the interface, not a second opinion.

## Just run it

```sh
V=~/.agents/skills/hassoub/bin/verify

$V https://your.app/            # a running web app  -> drives it, reports bugs
$V /path/to/vscode-extension    # an extension you built -> launches and observes
```

A bare target routes itself: a URL goes to the oracle lane, a directory with a
`package.json` to the editor lane. Nothing else needs to be known to start. Use
`--json` for one machine-readable object; exit **0 = healthy, 1 = findings,
2 = could not run**.

If anything is missing, `$V doctor` names the cause and refuses rather than
half-running.

## All commands

```
bin/verify doctor                     preconditions — run first, it blocks with named causes
bin/verify app    <url>               THE bug finder: scenario + oracle
bin/verify web    <url>               smoke test: do controls respond / error
bin/verify editor <ext-dir> [ws] [--keep]   a VS Code extension, both UI layers
bin/verify observe | click "<label>" | key <chord> | type <text> | stop
bin/verify dialog <verb> [args]       drive a native GTK file chooser
bin/verify repro  <repro.json> <url>  replay a saved finding
```

Scripts live in this skill's `bin/`. They are not on `PATH` — call them by
absolute path (`~/.agents/skills/hassoub/bin/verify`) or add that directory to
`PATH` first.

Add `--json` to any of them for one machine-readable object.
Exit code: **0 = healthy, 1 = findings, 2 = could not run.**

## Which command actually finds bugs

**`verify app` is the one with power.** It runs a scenario and judges it with a
validated oracle (three signals, gated 6/6 on a 3x2 discrimination matrix).

**`verify web` is a smoke test and is documented as weak on purpose.** It clicks
every control blind and reports errors. Measured: it is *silent on a build with
a known HTTP 500*, because it clicks Save with an empty form and never enters
the input that triggers the bug. Its `ok` means "nothing errored on a blind
click" — never read it as "the app works". The verdict carries a `scope` line
saying so.

Corollary: **`verify web` reporting ok is not evidence of a working app.** If
asked "does this work", run `verify app`.

## The oracle, in one table

| signal | catches | note |
|---|---|---|
| `state-divergence` | UI says success while authoritative state disagrees | the only one that catches a silent data loss — **invisible to screenshots** |
| `server-error` | any response ≥ 500 | cheap, high precision |
| `console-error` | uncaught page errors, benign noise filtered | weakest, medium severity |

4xx, favicon 404s and console warnings are deliberately **not** bugs. A harness
that cries wolf gets ignored, which is worse than no harness.

## Verifying a fix (fail-before / pass-after)

A finding you cannot replay is not evidence — "the harness stopped complaining"
is a weaker claim than "the bug is fixed". Run `verify repro` against the broken
build (expect exit 1) and the fixed one (expect exit 0). Both directions matter:
a repro that always fires proves nothing, one that never fires green-lights
regressions.

Note `verify repro` **normalises the exit code**: the underlying `qa-verify`
exits 0 when the bug REPRODUCES. Here, 0 always means healthy.

## Native file dialogs: pointer, never keyboard

A flow behind "Choose folder…" needs `verify dialog`. Measured on GTK3 portal
choosers, clean environment: **pointer 3/3, keyboard 0/5.**

Keyboard input *does* reach these dialogs — Ctrl+L opens the location bar and
characters appear — but the bar is unusable three ways: characters drop
(`/etc/hostname` landed as `/tc/hostname`, because `/` is itself a shortcut that
reopens the entry and eats the next key), the entry is remembered across dialog
sessions so new text merges into a stale path, and Return does not commit — only
clicking Select does.

```
verify dialog shot /tmp/d.png     # crop of the dialog; its pixels are window-relative
verify dialog at 300 299          # click a point read off that image
verify dialog at 300 299 double   # descend into a folder
verify dialog sidebar 2           # Home (sidebar is stable across views)
verify dialog select | cancel
```

Row *indexing* is unreliable — the list origin moves from y=84 in the "Recent"
landing view to y=131 once a breadcrumb bar appears. Prefer `at` with a
coordinate read off `shot`.

If more than one chooser is open, `verify dialog` **refuses** rather than
driving the wrong one. That is not caution for its own sake: stacked dialogs
silently corrupted a whole round of measurements here, with clicks landing on
one window and the confirm going to another.

## Editor extensions: start once, interact, stop

Without `--keep` this is a one-shot snapshot: it launches, observes once, and
tears the session down. That cannot answer "what happened when I clicked", so
for anything multi-step use `--keep` and drive it:

```
verify editor <ext-dir> <workspace> --keep
verify click "Choose folder…"      # click a control in the extension webview
verify key ctrl+shift+p            # chords work — this reaches the Command Palette
verify type "Argyris: Build"       # arbitrary text (CDP insertText)
verify observe                     # re-read BOTH layers after acting
verify dialog find                 # a native chooser lives on the HOST, not here
verify stop                        # always — --keep does not self-clean
```

`observe` reports how many native dialogs are open on the host, so a control
that answered by opening a file picker no longer reads as silence, and a dialog
dismissed behind your back shows up as the count returning to zero. The
QuickPick line also echoes what has been typed (`[typed: >Argyris: Build]`),
which is how you confirm the palette actually received a chord.

`--keep` refuses to start a second editor over a live one: one CDP port, one
editor. Run `verify stop` first.

## Editor extensions: check BOTH layers

`verify editor` launches the extension in an isolated nested desktop (so nothing
lands on the live one) and prints the extension's own UI **and** the VS Code
shell — notifications, QuickPicks, modal dialogs.

Both, because an extension often answers on the shell rather than in its
webview. Measured: after binding a folder, the extension's webview was
*byte-identical* while the workbench showed a QuickPick and a "3 files
inventoried" notification. A webview-only check calls that working flow dead.

The general rule, which has produced a false negative here more than once: **an
app's response can surface on a layer you are not watching** — the webview, the
app shell, or the host desktop (a portal dialog is a host service and appears
outside the app's own session entirely).

## Cost

`verify app` and `verify web` are headless — no window appears, and they work
over SSH with the monitor off. Only `verify dialog` and `verify editor` need a
live display; screenshots block entirely when every output is disconnected
(`doctor` reports this).

Prefer structured output to screenshots: reading a PNG costs far more than a
verdict line, and pixels cannot see a silent data loss anyway.

## When NOT to use this

- Unit/integration tests, or reading code for defects — this drives a *running* app.
- Native non-Electron GUIs beyond file dialogs. There is no AT-SPI on this
  machine, so there is no structured accessibility path; only screenshot +
  click, which is the weakest oracle available.

## Deeper reference (read only if needed)

- `~/projects/computer_use/qa/README.md` — oracle design, the discrimination
  matrix, and why realistic personas do *not* imply coverage
- `~/projects/computer_use/HANDOFF.md` — measured capability table and traps
- Skill `hyprland-computer-use` — lower-level capture/click/type primitives

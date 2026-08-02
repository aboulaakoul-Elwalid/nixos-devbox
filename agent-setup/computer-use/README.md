# computer_use

Work toward an agent-operable desktop on this NixOS/Hyprland workstation:
making the existing computer-use tooling trustworthy first, then building the
session isolation the rest depends on.

## Why this exists

`research.md` (a ChatGPT design document) proposes a large "agent computer
runtime". Before building any of it, its claims were tested against this actual
machine. Results are in **`FINDINGS_2026-07-28.md`** — read that first.

The short version:

- Nested Hyprland **works** — the document's biggest unproven premise holds.
  Independent window graph, independent capture, host untouched.
- The **input layer was silently broken**. `wtype` mistypes from ~character 14
  onward and exits 0 while doing it, so `hcu-type` (a bare `exec wtype`) had
  been corrupting agent GUI interactions all along.
- **AT-SPI does not exist here** (no a11y bus, no `gi` bindings), so any
  "structured accessibility actions" milestone needs real NixOS work first.
- `playwright-cli` now **works** as a deterministic verifier, but needed a
  NixOS-specific fix (`bin/pw-init`) — its bundled browsers and the `chrome`
  channel both fail here.
- Teardown is not clean by default: `SIGTERM` removes the Hyprland IPC socket
  (making `hyprctl instances` *look* clean) while leaving the process alive.
- Separate Wayland displays do **not** isolate single-instance GTK apps — they
  rendezvous over the shared session bus, so each desktop needs its own D-Bus.
- **Pixel capture disappears when the monitor is off.** Every DRM connector
  reads `disconnected`, Hyprland drops the output, and `grim` blocks forever —
  host and nested alike — while structured channels keep working. This is *not*
  DPMS: `dpms on` does not help, and there is no remote workaround.

## Verifying an app (start here)

Day-to-day use goes through the **`hassoub` skill**, which is the single front
door and is native to Claude Code, Codex CLI and OpenCode (one copy in
`~/.agents/skills`, symlinked into each agent's own root by `install.sh`).

```sh
verify doctor                    # preconditions; blocks with named causes
verify app    <url>              # THE bug finder: scenario + validated oracle
verify web    <url>              # smoke test only — see the caveat below
verify editor <ext-dir> [ws]     # a VS Code extension, both UI layers
verify dialog <verb> [args]      # native GTK file chooser, by pointer
verify repro  <repro.json> <url> # replay a saved finding
```

Exit code: 0 healthy, 1 findings, 2 could not run. `--json` for one object.

`verify web` is deliberately weak: it clicks controls blind and is **silent on a
build with a known HTTP 500**, because it never enters the data that triggers
it. Use `verify app` to answer "does this work".

Gate: `./test/test-verify-skill.sh` (14/14, and it goes red under
`QA_DISABLE_SIGNAL=state-divergence`).

## Sessions

```sh
./bin/acu-session start --name work      # isolated nested desktop
./bin/acu-session exec work -- chromium  # run something inside it
./bin/acu-session windows work           # structured window list
./bin/acu-session destroy work           # tear down, reaping orphans
```

## Layout

```
FINDINGS_2026-07-28.md   measured evidence + corrected mechanism
research.md              the original design document (external, unverified)
install.sh               deploy / drift-check the patched skills
skills/                  authoritative copies of the patched skill files
skills/
  hassoub/               THE front door — SKILL.md + bin/verify (see above)
  hyprland-computer-use/ low-level capture/click/type primitives
bin/
  acu-session            create/use/destroy isolated nested desktops
  acu-browser            persistent, authenticated browser profiles
  hcu-dialog             drive a native GTK file chooser by pointer
  pw-init                configure playwright-cli to work on NixOS
qa/
  bin/qa-run             the oracle (state-divergence / server-error / console)
  bin/qa-compile         trace -> declarative repro.json
  bin/qa-verify          replay a repro (exits 0 when the bug REPRODUCES)
  bin/qa-vscode          VS Code extension UI + workbench over CDP
  bin/qa-persona         LLM-directed user (actions only; judging stays with the oracle)
  sweep-web.sh           blind control sweep
  README.md              oracle design and its discrimination gate
test/
  nested-sink.sh         isolated nested-Hyprland test rig (fail-closed)
  test-hcu-type.sh       hcu-type regression suite (typing)
  test-hcu-click.sh      hcu-click fidelity suite (pointing)
  test-playwright.sh     deterministic browser-verifier smoke test
  test-acu-session.sh    session isolation + teardown gate
  test-verify-skill.sh   gate for the hassoub front door
  probe-capture.sh       when does nested screen capture actually work?
  probe-trigger.sh       characterises what actually triggers the wtype bug
  characterize-wtype.sh  length/threshold sweep
```

## Running the tests

Everything runs inside a nested compositor and never touches the live desktop.

```sh
./test/test-hcu-type.sh        # typing regression suite
./test/test-hcu-click.sh       # pointing fidelity suite
./test/test-playwright.sh      # browser verifier (headless, no window appears)
./test/test-acu-session.sh     # two concurrent isolated desktops
./test/test-verify-skill.sh    # the hassoub front door (14/14)
./qa/test-qa-oracle.sh         # oracle discrimination (6/6)
./qa/test-qa-repro.sh          # repro fail-before/pass-after (9/9)
./install.sh check             # repo vs ~/.agents in sync, AND skills linked?
```

The suite reports one expected failure — `raw-wtype-baseline` — which is the
upstream bug being worked around, and exits 0 when that is the only red.

To confirm the suite still has teeth:

```sh
HCU_TYPE_MAX_CHUNK=999 ./test/test-hcu-type.sh   # must fail
```

## Safety contract for the test rig

`nested-sink.sh` must never place a window on the live desktop. An early version
read the wrong JSON key (`wl socket` vs `wl_socket`), resolved an empty display,
and ghostty fell back to the host session. It now refuses to launch unless it
can positively verify a nested display distinct from the host's, and that guard
is mutation-tested against unresolved, spoofed, and dead targets.

The general rule this encodes, which applies to the whole project: **a tool that
cannot establish its target must block, not fall back.**

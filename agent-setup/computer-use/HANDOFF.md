# Handoff — 2026-07-28

> Updated end-of-day. Branch `feat/qa-harness`, ~22 commits, nothing pushed.
> Native file dialogs are solved (pointer, not keyboard) — see "RESOLVED: driving native dialogs".

# Handoff — overnight session, 2026-07-28

Branch `feat/input-layer-audit`, 4 commits, nothing pushed. Working tree clean.
Your desktop was left exactly as found (15 windows, all yours, no stray
processes or temp dirs).

## What was agreed and what got done

You picked "input layer" and then went to sleep with "continue autonomously".
I worked to the sequence in `FINDINGS_2026-07-28.md`, and everything below is
measured, not asserted.

| slice | status |
|---|---|
| Fix the input layer | **done** — 12/12, mutation-tested |
| Audit the *other* half of the input layer | **done** — `hcu-click` was already sound, 7/7 |
| Install a deterministic verifier | **done** — playwright works, 5/5 |
| Nested session manager | **done** — 13/13, capture path unverified (monitor was off) |

## The headline fix

`hcu-type` was `exec wtype "$@"`. `wtype` mistypes from ~character position 14
onward — shift-requiring characters resolve to the wrong key, usually `Tab` —
**and exits 0 while doing it**. Every agent GUI interaction long enough to trip
it has been silently corrupting text.

My first diagnosis ("more than 13 *distinct* characters") was **wrong**; a
28-distinct command line typing cleanly disproved it. The real boundary is
positional, so the fix bounds each `wtype` call to 13 characters — conservative
by construction and independent of the shift interaction I could not fully
explain. The code and findings say the mechanism is uncharacterised rather than
implying a derived bound.

## Three things I found by building the tests, not by reasoning

1. **Separate Wayland displays do not isolate single-instance GTK apps.**
   ghostty launched into session B appeared in session **A** — the second
   invocation messages the first over the shared session bus. Each session now
   gets a private `dbus-daemon`.
2. **Pixel capture disappears when your monitor is off.** Every DRM connector
   reads `disconnected` ⇒ Hyprland drops the output ⇒ `grim` blocks forever,
   host and nested alike, while `hyprctl`, CDP and the filesystem keep working.
   Verified over SSH that this is **not** DPMS — `dpms on` does nothing, and
   there is no remote workaround (nested headless output stays `0x0`; cage
   cannot take the DRM device Hyprland holds). Strongest practical argument for
   API-first/pixels-last: remotely, the pixel channel is simply *absent*.
3. **`SIGTERM` is not enough to kill a nested compositor.** It drops the IPC
   socket — so `hyprctl instances` *looks* clean — while the process lives on.
   Hyprland also forks, so there is a sibling pid `hyprctl` never reports.

## What I did wrong, and what it cost you

My test rig read `wl socket` instead of `wl_socket`, resolved an empty display,
and **ghostty fell back to your host session** — that is where those two
terminals on your screen came from. Fixed structurally: the rig and
`acu-session` now refuse to act unless they can positively verify a nested
display distinct from the host's, and that guard is mutation-tested against
unresolved, spoofed and dead targets. The general rule now encoded everywhere:
*a tool that cannot establish its target must block, not fall back.*

## Not verified — do not assume these work

- ~~**`acu-session capture`**~~ **now verified** (14/14, 2026-07-28 with the
  monitor on). It initially still failed: the no-focus-steal window rule parks
  agent desktops on `special:agent`, and a hidden window is never presented, so
  it never renders and screencopy blocks. Capture now briefly reveals the
  special workspace, grabs the frame, and hides it again (~1s flicker).
- **`hcu-type --strategy paste`** — passed once, failed once (ghostty forwarded
  Ctrl+Shift+V as an escape sequence instead of pasting). Excluded from the gate
  and documented as target-app dependent. **Do not treat it as the safe
  default** — the chunked path is.
- The `wtype` mechanism itself. The 13-character bound is an empirical ceiling.

## Run this when you wake up

```sh
cd ~/projects/computer_use
./test/test-hcu-type.sh        # typing         (12/12 + 1 expected control red)
./test/test-hcu-click.sh       # pointing       (7/7)
./test/test-playwright.sh      # browser verify (5/5)
./test/test-acu-session.sh     # sessions       (13/13; capture should now RUN)
./install.sh check             # repo vs ~/.agents in sync?
```

`~/.agents/skills/` is not a git repo, so this repo holds the authoritative
copies and `install.sh` answers "have they drifted?". Original `hcu-type` is
backed up beside it as `hcu-type.orig-2026-07-28`.

## Suggested next

1. Re-run the session gate awake to close the capture gap.
2. **Decide the fork.** `research.md` merges two projects: an agent-native
   desktop runtime (months) and synthetic-user QA for your app (days,
   browser-first). Your original motivation was testing software, and you now
   have the pieces for the QA path — isolated sessions, a trustworthy input
   layer, and a deterministic verifier. The runtime's next rung (AT-SPI) needs
   real NixOS work before it can even begin.
3. The six questions from your original research prompt — prior art, the oracle
   problem, persona diversity, cost/scale, reproducibility, auto-patch safety —
   are still unanswered. `research.md` never addressed them.


---

# End-of-day addendum — 2026-07-28

## What the QA harness became

A verification tool, not an autonomous doer — the framing that settled it was
"more about verification than actually doing the work".

| capability | state |
|---|---|
| oracle (state-divergence / server-error / console) | validated 6/6 on a 3x2 matrix, mutation-tested |
| trace -> repro -> fail-before/pass-after | 9/9 |
| LLM personas (`qa-persona`) | works, free via OpenCode |
| web sweep (`sweep-web.sh`) | works |
| VS Code extension UI (`qa-vscode`) | works — nested-frame CDP |
| isolated desktops (`acu-session`) | 14/14 incl. capture |
| event waits (`acu-session wait`) | works — 1438ms vs a 5000ms sleep |
| persistent browser profiles (`acu-browser`) | works |
| native file dialogs (`hcu-dialog`) | pointer 3/3; keyboard/location-bar unusable — see below |

## The finding that matters most about the oracle

It discriminates. Same oracle, same day:

    planted fixture bug      -> flagged
    deployed Argyris         -> flagged (404 on agent-summary while UI said "4/4 passed")
    VSCodium Argyris         -> flagged (demo-run path dead; works on the web build)
    stellantis-demo-app      -> SILENT (6 controls, 0 findings)

Broken -> findings, working -> silence. Without that last row the tool would
not be worth reading.

## Persona framing beats persona realism

Same model, same app, same budget, neither told the bug existed:

    naturalistic ("write notes like a real person")   5 notes, 0 findings
    edge-seeking ("you're messy, you use contractions") 6 notes, 4 findings

The persona that best emulates a real user found nothing, because ordinary
prose does not contain the character classes that break software. Do not
expect yield from "spawn realistic users and let them roam".

## RESOLVED: driving native dialogs (2026-07-28)

Routing works: `acu-session start --host-dialogs` puts native dialogs on the
live desktop; the default keeps them inside the session (the portal is
bus-activated, so the session's private D-Bus must be started with the nested
display).

**The earlier hypothesis — "GTK portal dialogs do not accept virtual-keyboard
input" — is WRONG.** The pointer experiment settled it, and the answer was the
opposite of what the evidence had suggested:

| input path | result |
|---|---|
| pointer: click row, click Select | **3/3 confirmed**, clean environment |
| keyboard: Ctrl+L, type, Enter | 0/5 confirmed |

Keyboard input *does* reach these dialogs — Ctrl+L opens the location bar and
typed characters appear on screen. The location bar is unusable for three
separate reasons, none of which is "input never arrives":

1. **Characters drop.** `/etc/hostname` repeatedly landed as `/tc/hostname`.
   The same string types perfectly into a terminal on the same seat, so
   `hcu-type` is not at fault. `/` is itself a chooser shortcut that reopens
   the location entry and eats the following keystroke.
2. **The entry persists across dialog sessions.** A fresh dialog can open
   holding a previous run's path, and new text merges into the leftover.
3. **Return does not commit.** Only clicking Select does.

So the working answer is: **navigate by pointer.** `bin/hcu-dialog` implements
it — `shot` to see the dialog, `at X Y` to click a point read off that image
(the shot is cropped to the window, so its pixels are already window-relative),
`sidebar N`, then `select`/`cancel`.

### Two measurement traps this exposed

**Stacked dialogs silently corrupt results.** A run of "3/3 success" was an
artifact: sixteen orphaned choosers had piled up, and the oracle ("is a chooser
still open?") plus the driver were resolving *different* windows. In a clean
environment that same recipe scored 0/5. `hcu-dialog` now refuses to act when
more than one chooser is open, and `probe-gtk-dialog.sh` dismisses its dialog
by clicking Cancel — `hyprctl closewindow` does nothing to a modal whose portal
request is still pending, which is how they accumulated.

**A guard that prints is not a guard that blocks.** The first ambiguity check
called `die` inside `$(_need)`, where `exit` only kills the subshell; the caller
carried on with empty geometry and clicked at `-47,22`. It was caught by
mutation-testing the guard (run every verb with zero and with two dialogs and
assert nothing moves), not by reading the code.

Reproduce: `qa/probe-gtk-dialog.sh pointer|keyboard|inspect` summons a real
portal FileChooser and reports whether it was confirmed.

---

# Lane: end-to-end GUI verification through a native dialog (2026-07-28)

The dialog work unblocked the flow that had been unverifiable. Driven start to
finish: VSCodium (nested, `--host-dialogs`) -> Argyris Home -> "Choose folder…"
-> native GTK folder chooser on the host, navigated by pointer to
`samples/demo-data/Nastran` -> confirmed with the app's custom
"Author from this solver output" button.

The extension received it. Evidence, from the app rather than from pixels:

    NOTIFICATION  Argyris case "Nastran": 3 files inventoried, 3 items needs attention.
    QUICKPICK     Several report families can read this output — pick one
        - nastran_modal   .../samples/demo-data/Nastran/beam-modes/beam_modes_m1.op2
        - nastran_static  .../samples/demo-data/Nastran/beam-modes/beam_modes_m1.op2

## The "Browse demo runs" finding was wrong TWICE

First it was reported as a silent no-op. Then, after your correction, as a
control that opens a file chooser. Neither is right. `home.openDemoData` calls
`vscode.env.openExternal(...)` on `samples/demo-data`, so the control opens the
folder in the **system file manager** — a Nautilus window appeared, which is
correct behaviour. The control that opens a chooser is "Choose folder…".

Lesson: two wrong diagnoses of the same control, both from inferring intent
instead of reading the handler. The handler is ~15 lines and settles it.

## The oracle gap this closed

After the folder was bound, the Argyris **webview was byte-identical**. A
webview-only oracle would have called a fully working flow dead — the exact
false positive this harness already made once, in a new disguise. The response
lived at the VS Code SHELL level.

`qa-vscode workbench` now reports notifications, QuickPicks and modal dialogs,
and `observe` includes it. Verified to discriminate: QuickPick open -> reported;
after Escape -> gone, while the sticky notifications correctly remain.

Rule worth generalising: **an app's response can surface on a layer the driver
does not own** — extension webview, app shell, or the host desktop. An oracle
scoped to one layer produces confident false negatives on the others.

## Keyboard is not one problem

`qa-vscode key <name>` injects via CDP `Input.dispatchKeyEvent`, straight into
the renderer. It works nested, unfocused, and headless — none of which `wtype`
manages. So for anything Chromium/Electron the keyboard is already solved by a
different channel, and the only genuinely keyboard-hostile surface left is the
native GTK chooser, where the pointer path in `hcu-dialog` is the answer.

    Chromium / Electron / web   -> CDP input        (works)
    ordinary native windows     -> wtype/hcu-type   (works, 12/12)
    GTK file chooser            -> pointer only     (hcu-dialog)

---

# Lane: the `hassoub` skill — one front door (2026-07-28)

The capabilities were solid; the INTERFACE was the unbuilt part. ~20 entry
points across four directories, three invocation conventions, none guessable
(`uv run --with websockets qa/bin/qa-vscode`, `QA_WORKSPACE=...`, `pw-init`
first). README mentioned neither `qa/` nor `hcu-dialog` and listed 2 of 4 tools.

Packaged as a skill rather than a bare CLI, because the skill substrate on this
machine already solves discovery: `~/.agents/skills` is canonical and both
`~/.claude/skills` and `~/.codex/skills` are symlinks back into it (OpenCode
shares the arrangement). One install becomes native to all three, so
`install.sh` now checks the LINK as well as the file — a skill present in
`~/.agents` but unlinked is installed and invisible.

    verify doctor | app | web | editor | dialog | repro     --json anywhere
    exit 0 healthy, 1 findings, 2 could not run

Gate: `test/test-verify-skill.sh`, 14/14, red under
`QA_DISABLE_SIGNAL=state-divergence` (exactly the two silent-drop rows).

## What testing the front door found

**`verify web` is near-useless as a bug finder, and now says so.** It is silent
on a build with a known HTTP 500 — it clicks Save with an empty form and never
types the apostrophe that triggers it. It also flagged that same Save as "NO
RESPONSE" on a KNOWN-GOOD build. So it was simultaneously missing a real bug and
inventing a fake one. Now: error signals are findings, no-response is a separate
advisory note, and the verdict carries a `scope` line. `verify app` is the lane
with measured discrimination.

**A cleanup that cannot see its targets does not run.** The editor lane declared
`sess`/`prof` as `local`, and the EXIT trap fires after the function returns —
so under `set -u` the trap aborted before destroying anything. It leaked a
nested compositor, 12 codium processes and the session dir while *looking* like
it had cleanup. Now script-scoped and asserted by the gate (before/after counts
of compositors, processes and profile dirs).

**The gate under-reported its own coverage.** Three cases ran inside `$( )`,
which forks a subshell, so their PASS lines and counter increments were
swallowed: it printed "passed: 9" having run 12 checks. Same failure class the
harness exists to catch — a green number that was not measuring what it claimed.

**`pkill -f` matched this script's own command line** and killed the caller
three separate times today. All teardown here is PID-based, with the match
pattern assembled at runtime so it cannot match the matcher.

---

# Field report -> fixes (2026-07-29)

First real outside use of `hassoub` found four gaps. All confirmed against the
code before fixing, all now closed and gated.

**1. `verify editor` could not do the "drive" half.** It launched, took ONE
snapshot, and tore the session down from its own EXIT trap — so answering "what
happened when I clicked" meant abandoning the tool, reading `cmd_editor`'s bash,
and hand-replicating its internals. Now a lifecycle: `--keep` plus
`observe|click|key|type|stop`, with state in `~/.cache/verify/editor.json`.
`--keep` refuses to start a second editor over a live one, and does NOT
self-clean — `verify stop` is required.

**2. `doctor` gave false confidence.** It reported `hcu-dialog: ok` because the
file existed and was executable, while the tool's only way to act — `hcu-click`,
which ships in the SIBLING hyprland-computer-use skill and is not on PATH — was
unreachable. The first real click died with "command not found" and left a live
dialog half-driven. Two fixes: `hcu-dialog` now resolves `hcu-click` up front
(env, PATH, its own dir, the sibling skill) and REFUSES to start without it,
rather than failing mid-gesture; and `doctor` now EXECUTES it instead of
stat-ing it. Mutation-tested by moving the binary aside: doctor goes red with
the precise cause.

An "ok" that means "the file exists" is the same defect class as a green test
that asserts nothing.

**3. No text entry.** `key` knew a fixed set of named keys, so there was no way
to open the Command Palette and run a command by name — which is how you split
"is the command handler broken" from "is the button wired wrong". Added
`type <text>` (CDP `Input.insertText`) and chords (`key ctrl+shift+p`). The
QuickPick readout now echoes the typed value (`[typed: >Argyris: Build]`), which
is what confirms a chord actually landed — previously unconfirmable.

**4. A dismissed dialog was invisible.** `observe` now always reports the count
of native dialogs open on the HOST, so a control that answered by opening a file
picker no longer reads as silence, and a dialog closing behind your back shows
up as the count returning to zero.

## What the report got right about what to keep

`qa-vscode click "<label>"`, `hcu-dialog` (once reachable), and — notably — the
written warnings. The doc said "check `hcu-dialog find` before trusting
silence", the reader did, and that is how a real product bug was caught instead
of being written off as "nothing happened". Docs that describe measured traps
rather than aspirations pay for themselves.

## A gate that reported red for working code

Extending the gate, three new checks failed while the behaviour was provably
correct by hand. Cause: `set -o pipefail` plus `cmd | grep -q`. The pipeline
takes the LEFT side's status, and those commands exit non-zero *because refusing
is the behaviour under test* — so correct behaviour was scored as failure
(`grep -q` also SIGPIPEs the writer). Fixed by capturing output first, then
grepping the variable. Exact mirror of the green-that-measures-nothing bug this
gate exists to catch, and worth remembering: **a red result deserves the same
scepticism as a green one.**

Two further gate bugs surfaced while extending it, both *false reds* — the
mirror of the green-that-measures-nothing failure this project keeps hitting:

* `set -o pipefail` + `cmd | grep -q`: the pipeline reports the LEFT side's
  status, and those commands exit non-zero *because refusing is the behaviour
  under test*. Correct behaviour scored as failure. Capture first, then grep.
* The leak check used a fixed `sleep 3` and an absolute baseline. An editor
  takes ~2s to exit and any process left by an earlier run polluted "before",
  so a clean teardown read as a leak. Now it normalises the baseline first and
  POLLS for the counts to return, rather than guessing an interval.

A red result deserves the same scepticism as a green one.

## Closeout: making invocation trivial (2026-07-29)

Two frictions remained between "claude use hassoub to test this" and a verdict:
the caller had to pick a lane, and `bin/verify` is not on `PATH`.

* A bare target now routes itself — a URL to the oracle lane, a directory with a
  `package.json` to the editor lane — and prints which lane it chose. Anything
  else is REFUSED with the command list, because guessing wrong would silently
  run a weaker check than the caller asked for (`verify web` looks like a test
  and is nearly blind).
* The routing note goes to stderr, so `--json` stays exactly one object. Gated.
* SKILL.md now opens with the absolute path and two runnable lines, and states
  that `bin/` is not on `PATH`.

Final gate: 28/28 including the editor leak check, red under
`QA_DISABLE_SIGNAL=state-divergence`.

    ~/.agents/skills/hassoub/bin/verify https://your.app/
    ~/.agents/skills/hassoub/bin/verify /path/to/vscode-extension

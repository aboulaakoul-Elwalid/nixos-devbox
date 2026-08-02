# Synthetic-user QA harness

The first consumer of the agent runtime. It exists to answer one question about
a running app: **did this session surface a real bug?**

Driving a browser is the easy part. The hard part — the part the original
research prompt asked about and `research.md` never answered — is the **oracle**:
telling a genuine defect apart from benign noise. That is what this harness is
built around.

## The oracle

Three signals, strongest first:

| signal | what it catches | why it matters |
|---|---|---|
| `state-divergence` | UI claims success while authoritative state disagrees | the only signal that catches an optimistic UI lying about a failed write — **invisible to screenshots** |
| `server-error` | any response ≥ 500 during the scenario | cheap, high-precision |
| `console-error` | uncaught page errors, benign noise filtered | weakest; medium severity only |

Deliberately **not** treated as bugs on their own: 4xx (often legitimate
validation), favicon/asset 404s, console warnings. Those are the classic
false-positive sources that make naive harnesses unusable — a harness that cries
wolf gets ignored, which is worse than no harness.

## Why there is a fixture app

An oracle that has only ever seen broken input is not known to *discriminate*.
A harness that flagged everything would pass a bug-only test.

`fixture/notes_app.py` therefore ships three builds and two scenarios, and the
gate requires the correct answer in all six cells:

| build | scenario | expected |
|---|---|---|
| `BUGGY:500` | apostrophe | **BUG** via `server-error` |
| `BUGGY:500` | plain | clean |
| `BUGGY:silent-drop` | apostrophe | **BUG** via `state-divergence` *only* |
| `BUGGY:silent-drop` | plain | clean |
| `FIXED` | apostrophe | clean |
| `FIXED` | plain | clean |

The **silent-drop** row is the point of the whole design. That build returns
HTTP **201**, logs no console error, and renders "Saved!" — while storing
nothing. No screenshot, vision model, or error-scraper can catch it. Only
re-reading authoritative state can. It proves `state-divergence` is load-bearing
rather than riding along with `server-error`.

## Running it

```sh
./qa/test-qa-oracle.sh          # the 3x2 discrimination gate (6/6 expected)
```

Confirm the gate still has teeth — crippling the oracle must turn it red:

```sh
QA_DISABLE_SIGNAL=state-divergence ./qa/test-qa-oracle.sh   # silent-drop row MUST fail
QA_DISABLE_SIGNAL=server-error     ./qa/test-qa-oracle.sh   # buggy500 row MUST fail
```

Run one scenario by hand:

```sh
./bin/pw-init /tmp/qa-ws
python3 qa/fixture/notes_app.py --port 8910 &
QA_WORKSPACE=/tmp/qa-ws ./qa/bin/qa-run \
  --url http://127.0.0.1:8910 --scenario save-apostrophe --out /tmp/out
```

Everything is headless — nothing appears on the desktop, and it works over SSH
with the monitor off.

## Findings become evidence: repro + fail-before / pass-after

A finding that cannot be replayed is not evidence — without a repro you can only
show the harness stopped complaining, which is a different claim from "the bug
is fixed".

```sh
./qa/bin/qa-compile --trace runs/x/trace.json --out repros/x   # trace -> repro.json
./qa/bin/qa-verify  --repro repros/x/repro.json --url URL      # replay it
./qa/test-qa-repro.sh                                          # the gate (9/9)
```

`qa-verify` exits **0 when the bug REPRODUCES** (its primary caller is a
fail-before check), so callers wanting the healthy direction must test for exit
1 explicitly rather than assuming success means healthy.

The gate requires **both** directions for every repro. A repro that always fires
proves nothing — it would "reproduce" on a healthy build too. One that never
fires is dead weight that silently green-lights regressions.

Two design decisions worth knowing:

- **Repros are declarative (`repro.json`), not generated code.** Generated
  shell/JS rots through quoting, escaping and environment drift, and a repro
  that fails for its own reasons is worse than none. Declarative replay goes
  through one audited runner, so semantics are identical every time. The
  trade-off: a `repro.json` needs this repo's runner, where a standalone spec
  could be handed to anyone. If that portability is wanted, emit a spec *from*
  `repro.json` rather than from the raw trace.
- **When several signals fire, the repro pins the user-facing HARM, not the
  mechanism.** On the 500 build both `state-divergence` and `server-error` fire;
  the compiler picks state-divergence, because a fix could plausibly change the
  status code while leaving the data loss in place. `--prefer` overrides this.

## Finding: realistic personas do NOT imply coverage

`qa-persona` drives the app as an LLM-directed user (via the local OpenCode
server, free tier, **cost 0**). The model chooses **actions only** — judging
stays with the validated oracle, because a model that both acts and judges
produces an unfalsifiable verdict.

Neither persona below was told the bug exists, what triggers it, or that it was
being tested. Same model, same app, same 6-step budget, same oracle. The ONLY
difference was the persona framing:

| framing | notes written | containing an apostrophe | findings |
|---|---|---|---|
| naturalistic — "write notes like a real person" | 5 | **0** | **0** |
| edge-seeking — "you're messy, you use contractions and possessives" | 6 | most | **4** |

The naturalistic persona wrote entirely plausible notes — *"Buy milk and eggs on
the way back"*, *"Call dentist to reschedule Wednesday appointment"* — and
triggered **nothing**. The edge-seeking one wrote *"Sarah's recipe…"*,
*"don't forget mum's birthday"*, *"they're good companion plants"* and hit the
bug four times.

**This is the central caution for persona-based QA.** The persona that best
emulates a real user — which is exactly what "synthetic user testing" asks for —
had a total blind spot, because ordinary prose does not contain the character
classes that break software. Realism and coverage are different objectives, and
optimising for the first actively costs you the second.

Practical consequence: do not expect yield from "spawn realistic users and let
them roam". Coverage has to come from explicit edge pressure in the persona
brief, or from a separate mutation/fuzz lane. Raw traces for both runs are in
`experiments/`.

This answers question 3 of the original research prompt (persona diversity /
mode collapse), which `research.md` never addressed.

```sh
QA_PERSONA_STYLE=edge ./qa/bin/qa-persona --url URL --steps 6 --out runs/p1
```

## What this is NOT yet

- **No triage or auto-patch.** Out of scope until there is a reason to trust
  batch findings.
- **Two persona framings, one app, n=1 each.** Directional evidence, not a
  measured effect size. Worth repeating before quoting the numbers.
- **Model calls are heavy.** OpenCode injects ~25k input tokens per call
  regardless of prompt size, so a 6-step run takes minutes. Free, but slow.
- **One app, two scenarios.** Scenario diversity is unmeasured; this is a
  correctness fixture, not a coverage claim.
- **Repro minimisation is trivial.** The step list is the scenario, not a
  delta-debugged minimum. Fine at this size, inadequate for long explorations.

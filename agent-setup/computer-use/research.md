---
title: "asayl - Autonomous QA Harness Design"
source: "https://chatgpt.com/g/g-p-6a2d92e1a788819185b905a43b5c3f3f-asayl/c/6a67825e-19a8-83ea-8837-2ed0ee351a86"
author:
published:
created: 2026-07-28
description: "Use ChatGPT to answer questions, write, create images, complete work, and code—all in one place. Get started for free or download the app."
tags:
  - "clippings"
---
Yesterday 5:08 PM

ALL\_SKILLS\_CONTEXT.md

File

I want to build an autonomous QA harness that spawns many LLM-driven "synthetic users" (personas), has each one operate a real running web/desktop application the way a human tester would (click, type, navigate, fill forms), runs many of these concurrently for hours, logs everything (console errors, network failures, screenshots, action traces), triages the logs into confirmed-bug vs. false-positive, and — for confirmed bugs — has an agent patch the code and re-run the exact failing scenario to confirm the fix. Think "computer-use agent as QA tester," but scaled to many personas, run unattended over a long horizon, with a bug-triage and self-patch loop wrapped around it, rather than one agent doing one task once. I already have the low-level building blocks (browser automation via CDP, desktop computer-use for native apps, a multi-agent orchestrator that can run parallel/pipelined agent stages with a "loop until K rounds find nothing new" pattern). What I don't have is validated knowledge of the following, please research and report on each: 1. \*\*Prior art\*\*: what products, frameworks, or research projects already do LLM-driven synthetic-user testing of software (not simple recorded E2E-test replay, but persona-driven exploratory agents)? Include both commercial QA-automation products and open-source/research projects. For each, note: how personas/scenarios are generated, whether it's web-only or also native/desktop, and whether it closes the loop (auto-patch) or only reports. 2. \*\*The oracle problem\*\*: how do existing systems decide "this session surfaced a real bug" vs. "the persona did something a real user never would" vs. "this is a benign console warning"? What signals do they use beyond raw error/exception detection (e.g. comparing against a known-good baseline run, visual diffing, assertion-based goals per persona)? 3. \*\*Persona/scenario generation quality\*\*: what's known about generating \*diverse, realistic\* user personas and edge-case scenarios from a PRD or app spec, such that the set actually covers real failure modes instead of converging on similar happy-path variations? Any research on measuring "scenario diversity" or avoiding mode collapse when an LLM generates its own test scenarios? 4. \*\*Cost/scale reality\*\*: for anyone running LLM agents as testers for multiple hours, what's the actual token/dollar cost per hour of coverage, and what tricks reduce it (cheaper model for the "drive the UI" loop, reserving an expensive model only for triage/patch judgment; caching; step budgets per persona)? 5. \*\*Non-determinism / reproducibility\*\*: since an LLM-driven persona won't take the exact same path twice, how do systems capture a reproducible repro (e.g. recording the exact action trace / DOM state / network fixtures at the moment of failure) so a fix can be verified deterministically rather than re-running the persona and hoping it fails again the same way? 6. \*\*Safety boundaries for the auto-patch loop\*\*: what practices exist for letting an agent both find AND patch bugs autonomously without human review per-patch — e.g. sandboxed target environment, disposable/synthetic data only, patch-then-verify-then-hold-for-human-merge rather than direct auto-merge? Please synthesize into: a short state-of-the-art summary, a recommended minimal architecture for a first working version, and the 2-3 biggest risks that make naive versions of this produce noisy/untrustworthy results. not just for qa to be honest i need to improve my computer use setup for my agents and that worth investing into i am sure first there is a lot repo online or hyrpland extras that can help, or probably some cli lanes that we can improve here on my machine the goal is to reach at the point where my agents can use my computer the way i do and also better than me also this will help a lot of with developing software

## Recommendation

**Yes: Hyprland can become something more powerful than ordinary “computer use.”** The right mental model is not:

```markdown
Codex sees screenshot → clicks screen
```

It is:

```markdown
Codex
→ reads the desktop as structured state
→ subscribes to compositor events
→ controls windows and workspaces directly
→ uses application APIs where available
→ falls back to accessibility
→ falls back to pixels only when necessary
```

That can be better than a conventional macOS computer-use setup in **composability, parallel isolated desktops, observability, policy control, and reproducibility**.

It will not automatically be better in application accessibility. macOS already has mature system APIs for accessible UI elements, synthetic input, screen capture, and virtual machines. [Apple Developer+2Apple Developer+2](https://developer.apple.com/documentation/applicationservices/axuielement_h?utm_source=chatgpt.com)

The advantage of your machine is that **the compositor itself is open, programmable, inspectable, and replaceable**.

## The real opportunity: an agent-native desktop

Hyprland already exposes most of the primitives needed to make the desktop into an environment an agent can reason over.

```markdown
Hyprland is not merely the screen.
Hyprland knows:

- every compositor instance
- every monitor
- every workspace
- every window
- every window’s PID, class, title, tags, geometry and state
- active focus
- keyboard and pointer devices
- layer-shell surfaces
- window opening, closing and movement events
- workspace and monitor transitions
- fullscreen and modal state
```

`hyprctl` exposes this information as JSON, and can target an individual Hyprland instance by ID or index. It also supports batched control operations. [Hypr Land Wiki+1](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/)

Your current local toolkit uses only a fraction of this: window geometry, focus, screenshots, absolute cursor movement, clicks and typing. Those scripts were explicitly verified against Hyprland 0.54.

ALL\_SKILLS\_CONTEXT

ALL\_SKILLS\_CONTEXT

The larger system can exploit several deeper layers.

---

## 1\. Hyprland can be the agent’s structured world model

Today a generic computer-use agent sees:

```markdown
a 1050 × 1680 image
```

A Hyprland-aware agent can instead see:

```markdown
{
  "instance": "agent-2",
  "monitor": "WL-1",
  "workspace": "project-argyris",
  "focused_window": {
    "stable_id": "...",
    "pid": 39122,
    "class": "codium",
    "title": "report.typ — Argyris",
    "position": [0, 0],
    "size": [1280, 800],
    "floating": false,
    "fullscreen": false,
    "tags": ["agent:2", "project:argyris"]
  },
  "other_windows": [...]
}
```

That immediately removes many common computer-use failures:

- clicking the wrong application;
- typing into the wrong terminal;
- losing a dialog behind another window;
- confusing similar windows;
- guessing screen geometry;
- failing because a window moved;
- repeatedly taking screenshots just to discover focus.

The compositor should be your **desktop state kernel**.

Pixels then answer:

> What is rendered inside this window?

Hyprland answers:

> Which window is it, where is it, who owns it, what state is it in, and what happened to it?

---

## 2\. The desktop can be event-driven instead of screenshot-polled

Hyprland exposes two Unix sockets:

```markdown
.socket.sock   → commands and queries
.socket2.sock  → live events
```

The event stream includes window opening, closing, title changes, workspace moves, active-window changes, monitor changes, fullscreen events, configuration reloads, input layout changes, and more. [Hypr Land Wiki+1](https://wiki.hypr.land/0.54.0/IPC/?utm_source=chatgpt.com)

Therefore an agent does not need this wasteful loop:

```markdown
screenshot
sleep
screenshot
sleep
ask model whether something changed
```

It can use:

```markdown
click Save
→ wait for window-title event
→ wait for dialog-open event
→ inspect the new dialog
```

Or:

```markdown
launch VSCodium
→ wait for openwindow matching class:codium
→ obtain stable window identity
→ assign agent and project tags
→ move it to the correct workspace
```

A proper event broker could expose:

```markdown
wait_for_window(...)
wait_for_window_closed(...)
wait_for_title(...)
wait_for_workspace(...)
wait_for_modal(...)
wait_for_fullscreen(...)
wait_for_idle(...)
wait_for_no_state_change(...)
```

This would reduce both latency and model usage substantially.

---

## 3\. Hyprland can directly perform many “GUI actions”

The current dispatcher system supports more than moving focus.

It can:

- target windows by PID, stable ID, address, class, title or tag;
- focus a specific window;
- send a shortcut to a selected window;
- control key-down and key-up state;
- move and resize windows;
- switch and move workspaces;
- alter z-order;
- set window properties;
- pin, group, tag or fullscreen windows;
- execute commands with initial window rules attached;
- create custom events on the event socket. [Hypr Land Wiki+2Hypr Land Wiki+2](https://wiki.hypr.land/Configuring/Basics/Dispatchers/?utm_source=chatgpt.com)

This means many operations currently implemented through global cursor movement can become deterministic compositor operations.

For example:

```markdown
Bad:
find window visually
→ click title bar
→ press Ctrl+S

Better:
target window by stable ID
→ send Ctrl+S directly to that window
→ wait for state evidence
```

Hyprland’s current dispatcher API explicitly accepts a target window for shortcut and key-state delivery. [Hypr Land Wiki](https://wiki.hypr.land/Configuring/Basics/Dispatchers/)

This will not replace mouse interaction inside arbitrary applications. But it removes the fragile focus-management layer around it.

---

## 4\. Windows can become owned agent objects

Hyprland’s tags are especially useful.

Instead of treating tags as cosmetic window-manager metadata, make them part of your runtime:

```markdown
agent:al-jazari
project:argyris
task:report-export
risk:workspace
phase:verify
artifact:expected
```

Hyprland can tag windows dynamically and target rules or dispatchers by those tags. Window rules can also route windows based on class, title, PID, modal state, workspace and other properties. [Hypr Land Wiki+1](https://wiki.hypr.land/Configuring/Window-Rules?utm_source=chatgpt.com)

Example lifecycle:

```markdown
Codex launches application
→ openwindow event includes PID/class/title
→ runtime matches process ancestry
→ assigns agent/task tags
→ moves window to agent workspace
→ applies geometry and capture policy
→ records it in task receipt
```

This gives you something macOS does not naturally provide at the window-manager level:

> **Explicit runtime ownership of every visible window.**

You could enforce:

```markdown
Agent A may interact only with windows tagged agent:A.
Agent B cannot focus, capture or close them.
Your live windows are tagged human:elwalid and remain blocked.
```

The policy must still be enforced in your daemon, but Hyprland gives you the identifiers and routing surface.

---

## 5\. Workspaces can become execution environments

Named and special workspaces can be used as more than human organization.

```markdown
workspace:agent-1-editor
workspace:agent-1-browser
workspace:agent-1-artifacts
workspace:agent-2-editor
workspace:agent-2-browser
```

Workspace rules can control monitor assignment, layout, gaps, rendering behavior and per-workspace layout. Selectors can match workspaces by name, monitor, visibility, special status, window count and fullscreen state. [Hypr Land Wiki](https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/?utm_source=chatgpt.com)

For a single nested agent desktop:

```markdown
Workspace 1 → source/editor
Workspace 2 → browser/app
Workspace 3 → logs/terminal
Special workspace → temporary dialogs/tools
```

The agent can operate them without dragging windows manually.

Window groups can provide tabbed application stacks:

```markdown
browser group:
  application
  documentation
  monitoring

editor group:
  VSCodium
  terminal
  diff viewer
```

This is not the strongest isolation boundary, but it is a strong deterministic organization primitive.

---

## 6\. Hyprland can host synthetic monitors

Hyprland can dynamically create outputs using three backends:

```markdown
wayland  → output appears as a window in a parent Wayland compositor
headless → virtual monitor with no physical display
auto     → chooses an appropriate backend
```

The official interface is:

```markdown
hyprctl output create headless agent-output
hyprctl output create wayland agent-output
```

Headless outputs are explicitly intended for VNC, RDP and Sunshine-style use, while Wayland-backed outputs support nested operation. [Hypr Land Wiki](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/?utm_source=chatgpt.com)

Current Hyprland also supports booting without a physical display; it creates a `HEADLESS-0` output and documents WayVNC, Sunshine and related software as access paths to a virtual Hyprland desktop. [Hypr Land Wiki](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Virtual-GPU/?utm_source=chatgpt.com)

This allows several different constructions.

## Construction A — One nested compositor per agent

```markdown
host Hyprland
├── nested Hyprland: agent-1
├── nested Hyprland: agent-2
└── nested Hyprland: agent-3
```

Each can have its own Wayland socket, windows, workspaces, focus and input seat.

## Construction B — Headless agent compositor

```markdown
headless Hyprland
├── HEADLESS-0
├── VSCodium
├── browser
├── terminal
└── WayVNC/Sunshine viewer
```

No agent window needs to appear on your desktop.

## Construction C — Remote disposable machine

```markdown
NixOS VM
└── headless Hyprland
    └── remote desktop server
```

That becomes appropriate for untrusted applications or more serious isolation.

The current Hyprland project identifies itself as independent rather than wlroots-based, so older wlroots-specific automation assumptions need fresh testing. The latest public release shown by the upstream repository is 0.55.2. [GitHub](https://github.com/hyprwm/hyprland?utm_source=chatgpt.com)

---

## 7\. Hyprland 0.55 adds a much deeper programming surface

This is important.

Your current scripts say they were verified on Hyprland 0.54. Upstream 0.55 deprecates the old Hyprland configuration format in favor of Lua.

ALL\_SKILLS\_CONTEXT

[Hypr Land Wiki](https://wiki.hypr.land/0.55.0/Configuring/Start/?utm_source=chatgpt.com)

The current Lua configuration supports callbacks such as:

```markdown
hl.on("window.active", function(window)
  -- react to the newly focused window
end)
```

Hyprland exposes compositor events directly to these Lua callbacks. [Hypr Land Wiki+1](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Expanding-functionality/?utm_source=chatgpt.com)

This means that some agent-runtime policy could run immediately inside the compositor configuration:

```markdown
hl.on("window.open", function(window)
  -- classify
  -- tag
  -- route
  -- apply policy
end)
```

Potential uses:

- automatically tag windows by launcher/process;
- route new windows to their owning agent;
- notify your external broker;
- detect unexpected windows;
- keep sensitive windows away from agent outputs;
- create a lease indicator;
- pause agents when your human workspace becomes active;
- attach task IDs to window state;
- launch monitoring services when a compositor starts;
- cleanly stop session services on shutdown.

Current Hyprland configuration can also bind Lua functions rather than only fixed commands. [Hypr Land Wiki](https://wiki.hypr.land/Configuring/Basics/Binds/?utm_source=chatgpt.com)

## Important warning

Do not immediately upgrade your workstation or rewrite the configuration around 0.55.

First establish:

```markdown
Hyprland --version
```

Then choose one lane:

```markdown
0.54:
  external daemon + IPC sockets

0.55:
  external daemon + Lua event policy
```

The external daemon should remain authoritative. The Lua layer should be a fast policy hook, not your durable state database.

---

## 8\. We can build compositor-native permissions

Current Hyprland has an optional permission system covering:

- direct screen capture;
- plugin loading;
- virtual or physical keyboards;
- cursor position access;
- input capture.

Rules can `allow`, `ask` or `deny` based on the requesting binary. The documentation specifically includes NixOS examples using derivation paths and Nix-generated executable paths. [Hypr Land Wiki](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/?utm_source=chatgpt.com)

That is extremely relevant.

You could define:

```markdown
agent observer:
  screencopy → allow only inside its compositor
  cursor position → allow
  input capture → deny
  plugin loading → deny

agent input broker:
  keyboard → allow
  screencopy → deny

unknown binaries:
  all sensitive permissions → deny
```

This is a more appropriate security model than giving one giant process unrestricted desktop access.

The policy could be generated declaratively by Nix:

```markdown
agentComputerUse.allowedScreenCapture = [
  grim
  agent-observer
];

agentComputerUse.allowedVirtualKeyboards = [
  agent-inputd
];
```

The exact module does not exist yet; that is something worth building.

---

## 9\. Screen observation can become a stream, not repeated PNGs

Your current toolkit uses `grim`, which is correct for explicit evidence snapshots.

ALL\_SKILLS\_CONTEXT

For continuous observation, Hyprland’s screen-sharing path uses:

```markdown
Hyprland
→ xdg-desktop-portal-hyprland
→ PipeWire
→ observer
```

The portal supports configurable frame limits, cursor modes, shared-memory fallback and persistent restore tokens. [Hypr Land Wiki+1](https://wiki.hypr.land/Useful-Utilities/Screen-Sharing/?utm_source=chatgpt.com)

The agent observer could therefore maintain:

- a low-frame-rate window or monitor stream;
- frame hashes;
- changed-region detection;
- cursor metadata;
- event-aligned screenshots;
- full-resolution capture only at failure points.

The loop becomes:

```markdown
Hyprland event says dialog opened
→ capture only dialog region
→ inspect it
```

rather than:

```markdown
capture full 1050 × 1680 screen every second
```

---

## 10\. We can attach a remote human takeover surface

WayVNC attaches to a Wayland session, creates virtual input devices and can expose a headless compositor display. [GitHub](https://github.com/any1/wayvnc?utm_source=chatgpt.com)

This enables:

```markdown
agent works headlessly
→ you open observer window
→ inspect live desktop
→ optionally take over input
→ release control back to agent
```

A good runtime should provide:

```markdown
watch-only mode
takeover mode
pause agent on takeover
resume agent after explicit release
```

Sunshine/Moonlight may be better for high-frame-rate or GPU-heavy applications; WayVNC is conceptually simpler for ordinary desktop automation. Both need local benchmarking on your NVIDIA configuration.

---

## 11\. A Hyprland plugin could make the compositor truly agent-native

Hyprland plugins have nearly complete access to compositor internals and can add or modify behavior unavailable through normal scripts. Upstream recommends event hooks over function interception and requires version pins because internal APIs evolve. [Hypr Land Wiki+1](https://wiki.hypr.land/0.51.0/Plugins/Development/Getting-Started/?utm_source=chatgpt.com)

A future `hypr-agent-bridge` plugin could expose:

```markdown
atomic window snapshot
window ownership metadata
agent leases
per-agent focus domains
input transactions
capture permissions
task-specific overlays
before/after action receipts
direct surface identity
deterministic virtual input
agent pause/takeover
```

It could also avoid races such as:

```markdown
query active window
→ another event changes focus
→ act on stale window
```

Instead:

```markdown
perform action only if window generation == expected generation
```

## But do not begin with a plugin

Recommended order:

```markdown
1. IPC and external daemon
2. Lua callbacks, if running 0.55
3. AT-SPI and app adapters
4. Plugin only for demonstrated compositor-level gaps
```

A plugin runs inside the compositor process. A bug can crash your whole desktop, and upgrades require exact compatibility work.

---

## 12\. Pyprland is a useful architectural reference

Pyprland already demonstrates an asynchronous companion daemon consuming Hyprland events and exposing commands through a plugin system. It supports event handlers such as `event_openwindow`, `event_closewindow` and `event_workspace`, with separate queues and plugin lifecycle management. [hyprland-community.github.io+1](https://hyprland-community.github.io/pyprland/Architecture_overview.html?utm_source=chatgpt.com)

It is not itself a computer-use runtime, but its architecture is close to what you need:

```markdown
Hyprland event socket
→ async daemon
→ internal state
→ plugin handlers
→ command socket
```

Possible decision:

```markdown
Use Pyprland directly:
  only if its plugin model fits cleanly

Borrow its architecture:
  likely the better option for agent-computerd
```

Likewise, `hyprland-rs` provides an existing Rust IPC wrapper, which could reduce the low-level socket work if a Rust implementation is preferred. [GitHub](https://github.com/orgs/hyprland-community/repositories?utm_source=chatgpt.com)

---

## What Codex could actually do with this

## Software-development loop

```markdown
Codex receives issue
→ creates isolated worktree
→ starts an agent Hyprland session
→ launches services in systemd scope
→ launches VSCodium, browser and terminal
→ compositor tags every window with task ID
→ Codex patches through filesystem/terminal APIs
→ browser is driven through CDP
→ native dialogs are driven through accessibility
→ compositor events confirm window transitions
→ visual checks use PipeWire/grim
→ exact task trace is retained
→ processes and desktop are destroyed
→ worktree remains for review
```

## Multi-agent development

```markdown
Manager
├── Agent 1 desktop: implementation
├── Agent 2 desktop: visual QA
├── Agent 3 desktop: docs/research
└── Agent 4 desktop: adversarial verification
```

They should not share one compositor. Each receives its own:

```markdown
Hyprland instance
XDG runtime
D-Bus
HOME or overlay
worktree
browser profile
clipboard
window graph
trace directory
```

## Long-horizon desktop tasks

Examples beyond QA:

- install and inspect development tools inside disposable environments;
- configure complex GUI applications;
- reproduce customer workflows;
- edit presentations in LibreOffice;
- inspect engineering/CAD outputs;
- exercise VSCodium extensions;
- debug native Electron apps;
- run cross-application data-entry flows;
- compare rendered application versions;
- generate documentation from observed behavior;
- learn reusable application procedures.

---

## Where this could beat macOS

## Hyprland/Linux advantage

### 1\. The window manager is an API

macOS exposes application accessibility objects and screen/input APIs, but you do not own or extend WindowServer.

With Hyprland you can:

```markdown
query compositor state
subscribe to its events
change its routing policy
create virtual outputs
run nested instances
write compositor plugins
modify the compositor itself
```

### 2\. Cheap parallel desktops

Hyprland instances can be nested or run headlessly. On Linux, they can be combined with namespaces, Bubblewrap, systemd scopes, containers and VMs.

macOS can run macOS and Linux VMs through Virtualization.framework, but that is a heavier boundary than launching another compositor process. [Apple Developer+1](https://developer.apple.com/documentation/virtualization?changes=latest_bet_8&utm_source=chatgpt.com)

### 3\. Declarative reproducibility

Nix can define:

- compositor version;
- configuration;
- tool versions;
- permissions;
- applications;
- systemd services;
- environment variables;
- GPU/runtime choices;
- sandbox policy.

An agent desktop can become a rebuildable artifact instead of a hand-configured workstation.

### 4\. Hybrid GUI/API operation

The agent can move freely among:

```markdown
shell
filesystem
D-Bus
Hyprland IPC
AT-SPI
CDP
application protocols
pixels
```

Recent computer-use research supports hybrid API-and-GUI operation rather than pure screen interaction. MCPWorld is explicitly built around API, GUI and hybrid tasks, with programmatic verification through white-box applications. [arXiv](https://arxiv.org/abs/2506.07672?utm_source=chatgpt.com)

### 5\. Full authority to improve the environment

When the agent repeatedly fails because a UI is inaccessible, Codex can:

- add accessibility labels to your application;
- add an MCP or D-Bus endpoint;
- write an application adapter;
- improve the Hyprland daemon;
- add a deterministic command;
- create a plugin;
- rebuild the Nix environment.

The machine can evolve around the agent.

## macOS advantage

macOS remains stronger today in:

- consistent accessibility implementation across many native applications;
- polished AXUIElement semantics;
- stable high-performance screen capture;
- straightforward synthetic event APIs;
- polished macOS VM APIs;
- ecosystem-wide conventions.

Apple’s accessibility layer represents UI controls as inspectable and controllable elements, Core Graphics can post keyboard and pointer events, and ScreenCaptureKit streams selected windows or displays. [Apple Developer+2Apple Developer+2](https://developer.apple.com/documentation/applicationservices/axuielement_h?utm_source=chatgpt.com)

So the honest decision is:

```markdown
macOS:
  better turnkey conventional desktop automation

Hyprland + NixOS:
  higher ceiling for a deeply customized,
  parallel, inspectable, agent-native computer runtime
```

The Linux version can become better, but only after we build the missing integration.

---

## What should exist on your machine

```markdown
NixOS
├── agent-computerd
│   ├── instance manager
│   ├── Hyprland IPC state graph
│   ├── socket2 event consumer
│   ├── action broker
│   ├── lease/policy engine
│   ├── AT-SPI bridge
│   ├── PipeWire observer
│   ├── app-adapter registry
│   └── trace/replay store
│
├── agent session templates
│   ├── nested-hyprland
│   ├── headless-hyprland
│   ├── dedicated-vt
│   └── vm-hyprland
│
├── adapters
│   ├── browser-cdp
│   ├── vscodium
│   ├── terminal-pty
│   ├── libreoffice-uno
│   ├── generic-atspi
│   └── pixel-fallback
│
└── Codex tools
    ├── computer_session_start
    ├── computer_observe
    ├── computer_wait
    ├── computer_act
    ├── computer_takeover
    ├── computer_replay
    └── computer_session_destroy
```

---

## The strongest new insight

**Do not expose Hyprland to Codex as fifty low-level commands.**

Expose a coherent desktop object model:

```markdown
interface Desktop {
  instances(): Instance[];
  windows(query?: WindowQuery): Window[];
  workspaces(): Workspace[];

  launch(spec: LaunchSpec): Promise<Window>;
  wait(condition: Condition): Promise<Event>;
  transact(actions: Action[]): Promise<Receipt>;

  capture(target: Window | Output): Promise<Frame>;
  takeover(session: Session): Promise<Lease>;
}
```

And:

```markdown
interface Window {
  stableId: string;
  owner: AgentId;
  task: TaskId;
  pid: number;
  application: string;
  title: string;
  tags: string[];
  workspace: string;
  geometry: Rect;

  focus(): Promise<void>;
  sendShortcut(keys: Keys): Promise<void>;
  move(workspace: string): Promise<void>;
  capture(): Promise<Frame>;
  accessibilityTree(): Promise<Node[]>;
}
```

This turns Hyprland from a collection of clever shell commands into the **kernel underneath Codex’s computer**.

---

## Implementation sequence

## P0 — Prove the compositor control plane

Build a thin daemon around existing IPC:

```markdown
structured instance/window/workspace state
+ socket2 event subscription
+ target-by-stable-ID
+ batch transactions
+ task/agent window tags
```

Gate:

```markdown
launch 3 apps in nested Hyprland
→ identify each deterministically
→ tag and route them
→ send shortcut to one without affecting the others
→ observe all transitions from events
→ zero screenshot use for window management
```

## P1 — Add agent desktops

```markdown
one nested instance
→ one headless instance
→ two concurrent isolated instances
```

Gate:

```markdown
two agents work concurrently
zero focus/clipboard/window interference
```

## P2 — Add application semantics

```markdown
CDP
+ AT-SPI
+ VSCodium adapter
+ terminal PTY
+ LibreOffice adapter
```

Gate:

```markdown
at least 80% of actions use structured channels
raw coordinates are under 20%
```

## P3 — Add Nix isolation and policy

```markdown
ephemeral HOME
private D-Bus
restricted repo mount
generated Hyprland permissions
systemd scope
cleanup receipt
```

## P4 — Compile successful behavior into reusable skills

```markdown
successful trace
→ semantic selectors
→ preconditions/postconditions
→ deterministic replay
→ reusable Codex skill
```

---

## Immediate decision

The next local work should not be another enhancement to `hcu-click`.

It should be a bounded repository such as:

```markdown
agent-computer-runtime/
├── crates/agent-computerd/
├── crates/hyprland-backend/
├── crates/trace-schema/
├── configs/hyprland-agent/
├── nix/module.nix
└── tests/nested-session/
```

The first vertical slice is:

```markdown
start nested Hyprland
→ detect its instance
→ consume its event socket
→ launch terminal
→ identify and tag terminal
→ target terminal with a shortcut
→ capture its window
→ terminate session cleanly
```

That single slice will tell us whether Hyprland is merely a convenient desktop for you—or the foundation of a genuinely agent-native local operating environment.

**My current judgment: it is probably the latter.** The strongest advantages are not animations or tiling; they are the IPC, event stream, instance model, synthetic outputs, dynamic routing, current permission system, Lua callbacks and the fact that Codex can modify the entire stack. What remains unproven is how reliably nested and headless instances work on your exact NixOS, NVIDIA and installed-Hyprland versions.

## Recommendation

**Do not keep adding independent “computer-use skills.” Build one local `Agent Computer Runtime`, then turn the existing skills into specialized clients of it.**

Your current skills already contain the right philosophy:

```markdown
API / CDP / test hook first
→ screenshot for visual truth
→ pixels only for GUI surfaces with no stronger interface
→ re-observe after every action
```

The weakness is that each skill currently operates as an isolated workflow:

```markdown
browser-use      → browser daemon
Playwright       → browser replay
hcu-*            → live Hyprland scripts
cage             → one offscreen app
Codex agents     → repo/worktree processes
verification     → separate Markdown receipts
local compute    → separate GPU/CPU reasoning
```

The project is to unify them into:

```markdown
task
→ capability router
→ isolated workspace + desktop + processes
→ structured observation
→ strongest available action channel
→ evidence after each action
→ deterministic verification
→ durable skill/trace
```

The target is not merely “computer use.” It is:

> **A reproducible agent workstation where Codex can build software, operate simulations, inspect results, use desktop applications, and improve its own environment without interfering with your work.**

---

## 1\. What you already have

Your current stack is stronger than it first appears:

- `browser-use` gives direct CDP control, raw JavaScript, network/console access, persistent Python state, and isolated concurrent browser sessions.
- Playwright gives stable element references, tracing, screenshots, and deterministic browser interaction.
- `hyprland-computer-use` gives monitor/window capture, Hyprland window discovery, absolute pointer movement, clicks, keyboard input, and one-app offscreen rendering.
- Your Codex registry already separates implementation, exploration, debugging, review, verification, architecture, and visual inspection roles.
- Your verification skills already define claims, oracles, gates, failure taxonomies, replay receipts, and independent verification.
- Your local-compute doctrine already separates host ownership by NixOS from project ownership by `uv`, and requires explicit CPU/GPU routing and resource evidence.
	ALL\_SKILLS\_CONTEXT
	10-codex-agent-personas
	90-high-tech-ml-eval-envs-skills
	60-local-deploy-compute-skills

The missing piece is **one runtime that composes them**.

---

## 2\. Improvement for every existing computer-use component

## A. hcu-capture

### Today

It captures:

- focused monitor;
- complete layout;
- a window found by title/class regex;
- an arbitrary region;
- optional downscaled image;
- geometry needed for coordinate conversion.

That is useful, but it is still a synchronous PNG tool using an ambiguous first regex match.

ALL\_SKILLS\_CONTEXT

### Upgrade

Turn it into a session-aware observation service:

```markdown
acu observe \
  --session agent-01 \
  --window win_42 \
  --include compositor,accessibility,pixels
```

Add:

- stable window identity, not regex-only selection;
- explicit Hyprland instance targeting;
- window-relative and desktop-relative coordinate spaces;
- screenshot hash and changed-region detection;
- before/after screenshot pairs;
- optional PipeWire frame stream;
- cursor position and visibility;
- accessibility-tree snapshot;
- compositor state snapshot;
- automatic secret-region masking;
- artifact metadata and checksum;
- capture only after relevant events instead of fixed polling.

Output should become structured:

```markdown
{
  "session_id": "agent-01",
  "window_id": "win_42",
  "timestamp": "...",
  "geometry": [0, 0, 1280, 800],
  "scale": 1,
  "image": "artifacts/frame-0042.png",
  "image_hash": "...",
  "state_hash": "...",
  "changed_regions": [[410, 220, 180, 70]]
}
```

### New role

`hcu-capture` becomes the pixel adapter beneath:

```markdown
computer.observe()
```

It should no longer be the full observation workflow itself.

---

## B. hcu-window

### Today

It lists windows and finds/focuses the first class/title regex match. It knows class, title, geometry, and focus history.

ALL\_SKILLS\_CONTEXT

### Problem

Titles are mutable and regexes are ambiguous. Two terminals or two VSCodium windows can match the same query.

### Upgrade

Create a persistent desktop object graph:

```markdown
{
  "id": "win_01HT...",
  "hypr_address": "0x...",
  "instance": "nested-agent-1",
  "pid": 48172,
  "process_start_time": "...",
  "class": "codium",
  "initial_title": "Argyris",
  "current_title": "report.typ — Argyris",
  "workspace": "agent-1-editor",
  "owner_agent": "al-jazari",
  "task_id": "task-382",
  "tags": ["agent:al-jazari", "task:382", "repo:argyris"]
}
```

Add:

- process ancestry;
- launch-token correlation;
- stable ID from address + process start identity;
- agent/task ownership;
- Hyprland tags;
- workspace routing;
- dialog-parent relationships;
- modal and fullscreen state;
- open/close/title/focus event history;
- lease state;
- commands targeting exact IDs.

Desired commands:

```markdown
acu window list --session agent-01
acu window wait --class codium --launched-by run_72
acu window tag win_42 agent:al-jazari
acu window send-shortcut win_42 ctrl+s
acu window capture win_42
```

### New role

`hcu-window` becomes:

```markdown
desktop registry + event-sourced window identity
```

This removes most wrong-window failures.

---

## C. hcu-click / hcu-move

### Today

The scripts combine Hyprland’s absolute cursor movement with `wlrctl` pointer clicks. This was verified against Hyprland 0.54 and operates on the real desktop pointer.

ALL\_SKILLS\_CONTEXT

### Problems

- global pointer side effects;
- no session target;
- no double-click;
- no drag;
- no scroll;
- no mouse-down/up transaction;
- no confirmation that the intended element received the event;
- coordinates are fragile after layout changes.

### Upgrade

Replace “click pixel” with an action router:

```markdown
semantic accessibility action
→ DOM/CDP action
→ compositor shortcut
→ window-relative visual target
→ absolute pixel fallback
```

API:

```markdown
{
  "session": "agent-01",
  "window": "win_42",
  "action": "activate",
  "target": {
    "role": "button",
    "name": "Run simulation"
  },
  "fallback": {
    "relative_point": [0.86, 0.91]
  }
}
```

Add complete pointer semantics:

- hover;
- single/double/triple click;
- button down/up;
- right and middle click;
- drag and drop;
- vertical/horizontal scroll;
- precise wheel deltas;
- window-relative coordinates;
- target bounds;
- action timeout;
- post-action state expectation.

Every action should be transactional:

```markdown
acquire session/window lease
→ confirm target state generation
→ perform action
→ await expected event/state delta
→ emit receipt
→ release lease
```

### New role

The old scripts remain a low-level fallback adapter:

```markdown
HyprlandPixelInputBackend
```

They should not be called directly by general agents.

---

## D. hcu-type

### Today

It sends text or keys through `wtype` to whichever window is focused. It cannot target a window itself.

ALL\_SKILLS\_CONTEXT

### Upgrade

Use this hierarchy:

```markdown
application API / terminal PTY
→ accessibility set-value
→ CDP DOM input
→ clipboard paste
→ virtual keyboard
→ physical-looking key sequence
```

Add:

- exact window/session target;
- focus-generation check;
- keyboard-down and keyboard-up;
- chords and sequences;
- Unicode-safe text;
- clipboard save/restore;
- paste mode for long text;
- human-like typing only when the application requires it;
- secret classification;
- prevention of typing secrets into an untrusted window;
- post-input value verification.

Examples:

```markdown
acu input set-text \
  --session agent-01 \
  --window win_42 \
  --role textbox \
  --name "Project name" \
  --value "Argyris"

acu input shortcut \
  --window win_42 \
  --keys ctrl,shift,p
```

For terminals, do not visually type shell commands unless the terminal itself is the product under test. Send commands through the PTY and use the visible terminal only as a verification surface.

---

## E. hcu-offscreen

### Today

It launches one full-screen application inside a temporary headless Cage compositor, waits a fixed interval, captures one screenshot, then kills the compositor. Input from the live Hyprland scripts cannot reach inside Cage. Electron is launched with GPU disabled to avoid black frames.

ALL\_SKILLS\_CONTEXT

ALL\_SKILLS\_CONTEXT

This is a good **render-smoke tool**, not an agent computer.

### Upgrade

Keep it, but narrow its purpose:

```markdown
hcu-offscreen:
one-application rendering smoke test
```

Add a separate full desktop session manager:

```markdown
acu session start \
  --backend nested-hyprland \
  --profile software-dev \
  --workspace /path/to/worktree
```

Session backends:

```markdown
nested-hyprland
headless-hyprland
dedicated-vt
browser-only
bubblewrap-hyprland
nspawn-hyprland
vm-hyprland
cage-render-smoke
```

The nested/headless Hyprland backend should support:

- multiple applications;
- independent pointer and keyboard;
- separate workspaces;
- separate Wayland socket;
- separate Hyprland IPC;
- private clipboard;
- private D-Bus;
- private AT-SPI bus;
- ephemeral home;
- optional remote viewer;
- pause/resume;
- snapshot/restore;
- clean teardown.

This is the biggest concrete upgrade.

---

## 3\. Improvements to the browser stack

## A. browser-use

### Today

It already has the correct exploratory-browser primitives:

- CDP;
- DOM/JavaScript inspection;
- screenshots;
- network and console diagnosis;
- multiple fully isolated sessions with separate daemons, sockets, PIDs, browsers, and tab ownership;
- disposable browser profiles.
	ALL\_SKILLS\_CONTEXT

### Upgrade

Make each browser session a child of a general computer session:

```markdown
ComputerSession
└── BrowserSession
    ├── browser process
    ├── profile
    ├── CDP endpoint
    ├── console stream
    ├── network stream
    ├── downloads
    └── trace
```

Add:

- session manifest and owner;
- process resource limits;
- profile snapshot/reset;
- HAR capture;
- browser storage snapshot;
- automatic console/network deltas after each action;
- DOM and accessibility snapshot hashes;
- route and WebSocket capture;
- deterministic seed/fixture injection;
- localhost service health awareness;
- per-step token and time budget;
- action deduplication;
- exact correlation between browser action and backend logs;
- handoff to Playwright when an exploratory trajectory succeeds or fails.

### Important design change

`browser-use` should be the:

```markdown
probabilistic explorer
```

It should not also be the deterministic verifier.

---

## B. Browser-use Python library skill

### Today

This skill contains library guidance for:

- agent lifecycle;
- custom tools;
- hooks;
- output and memory control;
- monitoring;
- parallel execution;
- sensitive data;
- browser configuration.
	ALL\_SKILLS\_CONTEXT

### Upgrade

Use it as the implementation substrate for a `BrowserAgentBackend`, but remove browser-library details from general agent prompts.

Build explicit hooks:

```markdown
on_session_start
before_action
after_action
on_state_change
on_console_event
on_network_event
on_download
on_failure
on_session_end
```

Every hook writes to your unified `ActionEvent` schema.

Do not let each browser agent invent its own logging format.

---

## C. Playwright

### Today

The skill gives snapshots, stable element references, tracing, screenshots, and deterministic terminal-driven browser automation.

30-coding-repo-workflows

### Upgrade

Make Playwright the **repro compiler and browser verifier**.

Flow:

```markdown
browser-use exploration trace
→ normalize successful semantic actions
→ minimize the action sequence
→ generate Playwright scenario
→ replay on clean fixture
→ require fail-before / pass-after
→ commit as regression test
```

Add commands such as:

```markdown
acu repro compile run_82 --backend playwright
acu repro minimize repro_14
acu repro verify repro_14 --commit baseline
acu repro verify repro_14 --commit candidate
```

Playwright should own:

- exact action replay;
- trace viewer artifact;
- HAR fixture replay;
- deterministic assertions;
- screenshots for visual checkpoints;
- browser matrix;
- failed-step minimization.

This is a much stronger division:

```markdown
browser-use discovers
Playwright proves
```

---

## 4\. Improvements to the NixOS skill

## nixos-desktop

### Today

The uploaded skill is only a routing wrapper telling Codex to load the canonical local NixOS desktop instructions before changing Hyprland, Home Manager, Waybar, Ghostty, Mako, Walker, PATH, or workstation tooling.

60-local-deploy-compute-skills

### Upgrade

Create a real declarative module for the runtime:

```markdown
modules/agent-computer-runtime/
├── default.nix
├── packages.nix
├── service.nix
├── hyprland-live.nix
├── hyprland-nested.nix
├── portals.nix
├── accessibility.nix
├── input.nix
├── sandbox.nix
├── resource-policy.nix
└── observability.nix
```

It should declare:

- runtime package version;
- exact Hyprland version compatibility;
- `grim`, `slurp`, `wtype`, `wlrctl`, `wl-clipboard`;
- AT-SPI dependencies;
- PipeWire and portals;
- browser dependencies;
- nested/headless session templates;
- Bubblewrap/systemd-nspawn support;
- user service and socket;
- log and artifact directories;
- tmpfiles cleanup;
- permission policy;
- Waybar integration;
- emergency-stop bind;
- MCP registration;
- systemd targets.

Example configuration:

```markdown
services.agentComputerRuntime = {
  enable = true;

  liveDesktop.enable = true;

  nestedHyprland = {
    enable = true;
    maxSessions = 3;
    defaultResolution = "1440x900";
  };

  isolation.default = "workspace";
  browser.maxSessions = 6;

  resources = {
    totalMemoryMax = "32G";
    perSessionCPUQuota = "300%";
    gpuPolicy = "leased";
  };
};
```

NixOS should make the agent computer **rebuildable**, not merely installed.

---

## 5\. Improvements to the Codex agent personas

Your current personas are already correctly differentiated:

- Al-Biruni explores;
- Al-Jazari implements;
- Al-Razi diagnoses;
- Ibn al-Haytham reviews adversarially;
- Mimar Sinan plans;
- Verifier executes independent checks;
- Multimodal Looker inspects visual evidence.
	10-codex-agent-personas

The improvement is to give each persona an explicit **computer authority profile**.

## Al-Biruni — explorer

```markdown
desktop:
  observe: true
  interact: false
repo:
  read: true
  write: false
network:
  docs: true
```

Can inspect:

- repository;
- running app;
- desktop graph;
- screenshots;
- logs.

Cannot mutate.

## Al-Jazari — implementer

```markdown
desktop:
  session: isolated
  interact: true
repo:
  owned_worktree: write
  forbidden_paths: enforced
system:
  host_config: false
```

Receives:

- one worktree;
- one nested desktop;
- one terminal PTY;
- one browser profile;
- declared commands;
- fixed acceptance gate.

## Al-Razi — debugger

Gets:

- failing trace;
- original environment snapshot;
- process logs;
- browser/network logs;
- desktop events;
- controlled diagnostic substitutions.

No blind retries. Your eval skills explicitly require preserving the first failure, replaying at concurrency one, and distinguishing task, harness, provider, runtime, tool, and scoring layers.

90-high-tech-ml-eval-envs-skills

## Verifier

Gets a fresh environment and no write access to the candidate.

It must:

```markdown
reproduce original failure
→ run candidate
→ replay exact scenario
→ run nearby success path
→ inspect artifacts
```

## Judge

Reviews:

- whether the goal was actually met;
- whether the GUI result matches the product claim;
- scope creep;
- unsupported success claims;
- rollout and rollback risk.

## Multimodal Looker

Should receive crops and state metadata rather than the whole desktop whenever possible:

```markdown
window identity
+ expected UI state
+ changed regions
+ before/after frames
```

This reduces visual ambiguity.

---

## 6\. Improvements to verification skills

## verification-loop

### Today

It already requires:

- claim;
- oracle;
- metric;
- slices;
- baseline;
- candidate;
- gates;
- failure taxonomy;
- replay receipt;
- decision.
	90-high-tech-ml-eval-envs-skills

### Upgrade

Make the runtime produce these artifacts automatically.

Every serious desktop run should write:

```markdown
runs/<run-id>/
├── manifest.json
├── environment.json
├── actions.jsonl
├── compositor-events.jsonl
├── accessibility-events.jsonl
├── process-events.jsonl
├── browser-events.jsonl
├── screenshots/
├── network/
├── console/
├── files-changed.json
├── gates.json
├── failure.json
└── receipt.md
```

The Markdown receipt should be rendered from machine-readable data, not manually composed by the acting agent.

## pr-gates

Extend repo gates with a computer-use section:

```markdown
## Behavioral gate

- Start clean isolated desktop
- Launch candidate build
- Replay scenario \`save-report-001\`
- Assert expected file exists
- Assert no uncaught process/browser errors
- Capture final visual artifact
- Compare against accepted structural/visual oracle
```

## handoff-template

Add:

- session snapshot or replay ID;
- desktop backend;
- active processes;
- open windows;
- worktree identity;
- last confirmed action;
- exact resume command.

## deslop

Use the agent desktop to inspect the real resulting application, not just the diff. A smaller code diff that breaks the interface is not a successful de-slop pass.

---

## 7\. Improvements to local compute and simulation skills

Your local-first policy correctly treats the workstation as:

- 10-core/20-thread CPU;
- about 63 GiB RAM;
- RTX 3060 12 GiB;
- Nix as host owner;
- `uv` as Python-project owner.
	60-local-deploy-compute-skills

A complete runtime needs to convert that doctrine into a scheduler.

## Add resource leases

```markdown
CPU lease
RAM lease
GPU lease
display/compositor lease
browser lease
port lease
worktree lease
artifact-disk lease
```

Example:

```markdown
task: run-cae-simulation
resources:
  cpu: 8
  memory: 24GiB
  gpu:
    count: 1
    memory_budget: 10GiB
  disk: 40GiB
  max_wall_time: 3h
```

## Simulation operating loop

```markdown
prepare isolated project environment
→ validate inputs and solver identity
→ launch simulation through CLI
→ monitor process, CPU, GPU, disk and logs
→ detect stall/failure
→ inspect GUI only where needed
→ collect result artifacts
→ open postprocessor in agent desktop
→ generate plots/screenshots
→ compare against oracle
→ produce receipt
```

Computer use is particularly valuable for:

- proprietary postprocessors;
- CAD/CAE tools with incomplete CLI surfaces;
- plot and animation inspection;
- native dialogs;
- simulation dashboards;
- vendor GUI configuration;
- checking whether generated artifacts render correctly.

But the solver itself should remain CLI/API-driven whenever possible.

## GPU protection

Authoritative GPU jobs should be serialized where necessary, and benchmarks must record competing processes, warmup, variance, hardware identity, and correctness across representative slices. Your existing kernel/eval skills already require this discipline.

60-local-deploy-compute-skills

---

## 8\. New skills to add

Do not create one giant 2,000-line `computer-use/SKILL.md`.

Create a small routed family.

## 1\. computer-runtime

The top-level router:

```markdown
Choose:
CLI/API → browser → accessibility → pixels
Choose:
live → nested → headless → VM
Establish:
scope, authority, gates, artifacts, cleanup
```

## 2\. agent-desktop

Manages lifecycle:

```markdown
start
inspect
pause
resume
view
take over
snapshot
reset
destroy
```

## 3\. desktop-observe

Combines:

```markdown
Hyprland state
+ socket events
+ accessibility
+ pixels
+ process state
+ notifications
```

## 4\. desktop-act

Provides semantic and fallback actions with policy enforcement.

## 5\. computer-replay

Compiles traces into deterministic replay programs.

Backends:

```markdown
Playwright
shell/PTY
Hyprland event/action script
accessibility script
mixed replay
```

## 6\. application-adapter

Defines how a known application should be controlled.

Initial adapters:

```markdown
Chromium
VSCodium
Ghostty
LibreOffice
file manager
PDF viewer
image viewer
simulation postprocessor
```

## 7\. simulation-operator

Combines local compute, process management, artifact capture, visualization, and result verification.

## 8\. desktop-eval

Benchmarks agent-computer performance:

```markdown
task success
wrong-window actions
wrong-target actions
human intervention
semantic-action ratio
pixel fallback ratio
mean steps
wall time
token use
replay success
cleanup success
```

---

## 9\. Introduce a Skill Contract v2

Today most skills are procedural prose. For autonomous use, every skill should have machine-readable declarations.

```markdown
name: export-argyris-report
version: 1

requirements:
  session: isolated
  applications:
    - codium
    - chromium
  filesystem:
    writable:
      - "${WORKTREE}"
    forbidden:
      - "${HOME}/.ssh"
      - "${HOME}/.gnupg"

authority:
  network: localhost-only
  repo_write: owned-worktree
  external_side_effects: none

inputs:
  case_path: path
  export_format:
    enum: [pptx, pdf]

success:
  - artifact_exists
  - export_receipt_valid
  - app_has_no_uncaught_error

artifacts:
  - report
  - screenshots
  - action_trace
  - gate_results

cleanup:
  - terminate_processes
  - destroy_browser_profile
  - destroy_desktop_session
```

This gives the orchestrator enough information to prepare the computer before invoking the agent.

---

## 10\. The complete runtime architecture

```markdown
Codex / OpenCode / task orchestrator
                 │
                 ▼
        Capability and policy router
                 │
       ┌─────────┼───────────┐
       ▼         ▼           ▼
  Direct tools Browser     Desktop
  shell/API    CDP/PW      Hyprland/AT-SPI/pixels
       │         │           │
       └─────────┼───────────┘
                 ▼
          agent-computerd
     ┌───────────┼────────────┐
     ▼           ▼            ▼
Session mgr   State graph   Action broker
     │           │            │
     ▼           ▼            ▼
Nix sandbox  event store   policy/leases
     │           │            │
     └───────────┼────────────┘
                 ▼
       trace + replay + receipts
                 │
                 ▼
       verifier / reviewer / human
```

## agent-computerd responsibilities

- allocate session;
- allocate worktree;
- establish ephemeral home;
- launch processes;
- identify and tag windows;
- expose desktop object graph;
- select action channel;
- enforce permissions;
- capture events and artifacts;
- manage CPU/RAM/GPU;
- pause on human takeover;
- clean up;
- compile receipts.

---

## 11\. Work modes

## Mode 1 — Human copilot

Agent operates your live desktop only with a lease.

Use for:

- showing you something;
- helping with one dialog;
- manipulating an application already open;
- collaborative debugging.

Rules:

```markdown
one agent
human activity pauses agent
no secret surfaces
no destructive actions
```

## Mode 2 — Agent workstation

Nested Hyprland with ephemeral home.

Use for:

- ordinary software development;
- browser testing;
- VSCodium extension work;
- LibreOffice/report work;
- simulation postprocessing;
- long-running tasks.

This should be the default.

## Mode 3 — Full physical machine

Dedicated user on another VT.

Use for:

- hardware/display fidelity;
- GPU-heavy GUI;
- CAD/fullscreen applications;
- tasks where nesting changes behavior;
- overnight exclusive runs.

## Mode 4 — Untrusted workstation

VM or systemd-nspawn/Bubblewrap-backed desktop.

Use for:

- unknown software;
- adversarial websites;
- installers;
- potentially destructive test cases;
- customer-provided binaries.

---

## 12\. What this gives you for software development

A complete development task becomes:

```markdown
issue/spec
→ create isolated worktree
→ start nested Hyprland
→ start repo services
→ open VSCodium/browser/terminal
→ implement through filesystem and PTY
→ verify UI through CDP/accessibility/pixels
→ capture visual regressions
→ run tests
→ ask independent verifier
→ produce diff + artifacts + replay receipt
→ leave branch for human merge
```

It also enables agents to improve the development environment itself:

- discover repeated manual steps;
- compile them into skills;
- add app adapters;
- add accessibility labels to your applications;
- replace pixel workflows with APIs;
- improve Nix modules;
- add deterministic verification;
- measure whether the improvement actually reduces failures.

---

## 13\. What this gives you for simulation and engineering work

```markdown
input case
→ validate versions and inputs
→ launch solver
→ monitor resources/logs
→ detect completion or failure
→ open output in postprocessor
→ inspect plots/animations
→ extract evidence
→ compare against requirements
→ generate report/deck
→ preserve full run receipt
```

For Argyris, that can become:

```markdown
solver outputs
→ META or postprocessor agent desktop
→ extract plots and KPIs
→ compile Argyris Case
→ open governed report UI
→ generate deck
→ verify evidence links
→ export PPTX/PDF
```

This is exactly the kind of work where API, CLI, simulation evidence, visual inspection, and document applications must coexist.

---

## 14\. What not to build yet

Do not start with:

- a Hyprland plugin;
- your own compositor;
- a universal vision model;
- ten simultaneous desktops;
- unrestricted `/dev/uinput`;
- automatic system package installation;
- autonomous merge/deployment;
- a complex distributed scheduler;
- a second orchestration framework.

Start with one vertical slice.

---

## 15\. First implementation plan

## P0 — Upgrade the existing Hyprland skill

Build:

```markdown
session-aware window identity
+ Hyprland event consumer
+ stable window targeting
+ nested Hyprland launcher
+ complete input primitives
+ structured action receipts
```

### Gate

```markdown
start nested Hyprland
→ launch terminal, VSCodium and browser
→ identify all three
→ control each independently
→ edit and save a synthetic file
→ verify through filesystem and screenshot
→ destroy session
→ no interference with host desktop
```

## P1 — Unified browser and desktop session

Attach:

- one isolated browser;
- Playwright tracing;
- console/network capture;
- worktree and services;
- one unified run manifest.

### Gate

```markdown
agent edits a small web app
→ starts it
→ browser-use explores it
→ Playwright verifies it
→ final screenshot and test artifacts retained
```

## P2 — Accessibility and application adapters

Add AT-SPI and adapters for:

```markdown
VSCodium
LibreOffice
file manager
```

Target:

```markdown
≥80% structured actions
≤20% coordinate actions
```

## P3 — Compute and simulation operator

Add:

- resource leases;
- process monitoring;
- GPU ownership;
- simulation manifests;
- artifact collectors;
- postprocessor workflow.

## P4 — Autonomous compounding

A successful trace can propose:

```markdown
new deterministic skill
new app adapter
new verification gate
new failure regression
```

But another agent must verify the proposed improvement before it becomes part of the runtime.

---

## Final decision

Your old skills should evolve like this:

```markdown
browser-use
→ exploratory web operator

Playwright
→ deterministic web verifier/repro compiler

hyprland-computer-use
→ low-level live/nested desktop adapter

hcu-offscreen
→ one-app render-smoke backend

nixos-desktop
→ declarative runtime installer and policy owner

Codex personas
→ agents with explicit computer authority profiles

verification-loop
→ machine-generated run evidence and replay contracts

local-first-compute
→ CPU/RAM/GPU/session scheduler

pr-gates
→ behavioral and visual acceptance gates

handoff
→ resumable computer-session state
```

The single strongest product to build is:

> **An isolated nested-Hyprland development workstation that Codex can create, operate through structured APIs plus visual fallback, verify, and destroy—while you continue using the host desktop.**

That one slice becomes the foundation for QA, coding, simulations, report generation, research workflows, desktop applications, and eventually a machine that continuously teaches its agents how to operate it more reliably.

SKILL(2).md

File

i want also to not forget about browser use we have

Absolutely. **Browser-use should be one of the central pillars of the system, not a minor adapter under Hyprland computer-use.**

The corrected architecture is:

```markdown
Agent Computer Runtime
├── Browser Runtime        ← browser-use + CDP
├── Browser Verifier       ← Playwright
├── Desktop Runtime        ← Hyprland + AT-SPI + pixels
├── Process Runtime        ← shell / PTY / systemd scopes
├── Workspace Runtime      ← worktrees / ephemeral homes
└── Evidence Runtime       ← traces / logs / screenshots / receipts
```

Your uploaded `browser-use` skill is already substantially stronger than generic screenshot-based browser control. It supports real CDP interaction, DOM inspection, JavaScript execution, screenshots, raw protocol calls, console/network diagnosis, disposable profiles, and local or remote browsers.

SKILL

## Browser first, desktop second

For anything rendered in Chromium, the priority should be:

```markdown
1. CDP / DOM / browser-use
2. Playwright selectors and assertions
3. browser accessibility tree
4. screenshot / visual grounding
5. raw coordinates
```

Hyprland should manage:

- which browser process belongs to which agent;
- which nested desktop contains it;
- window ownership and geometry;
- lifecycle and isolation;
- OS dialogs;
- file pickers;
- clipboard;
- downloads;
- application switching.

But once the browser page is open, **browser-use should take control from Hyprland**.

Bad:

```markdown
Hyprland screenshot
→ visually find browser
→ visually find form
→ click coordinates
→ type globally
```

Better:

```markdown
Hyprland identifies exact browser window
→ browser-use attaches to its CDP endpoint
→ DOM/CDP controls the page
→ Hyprland intervenes only for OS-level surfaces
```

## Two browser execution modes

## 1\. Browser-only agent session

This should be the default for web work:

```markdown
agent
→ isolated Chromium process
→ isolated profile
→ dedicated CDP port
→ browser-use session
```

Use it for:

- web application development;
- exploratory QA;
- research;
- scraping;
- admin consoles;
- dashboards;
- documentation;
- frontend debugging;
- API/network diagnosis.

It is much cheaper and simpler than starting a whole nested Hyprland desktop.

Your existing tooling already supports disposable Chromium profiles and independent browser sessions. The earlier combined skill context also describes isolated daemon/socket/PID ownership for concurrent sessions.

ALL\_SKILLS\_CONTEXT

## 2\. Browser inside an agent desktop

Use this when the workflow crosses browser and operating-system boundaries:

```markdown
nested Hyprland
├── Chromium controlled through browser-use
├── VSCodium
├── terminal
├── file manager
└── LibreOffice
```

Necessary for:

- native file-upload dialogs;
- downloads opened in desktop applications;
- drag-and-drop from file manager;
- browser-to-VSCodium workflows;
- OAuth or external application handoffs;
- testing Electron/browser/native integration;
- opening generated PDF/PPTX files;
- multi-application engineering workflows.

The browser remains CDP-controlled. The nested desktop manages everything around it.

## Improve the existing browser-use skill

## 1\. Session ownership

Every browser should belong to an explicit runtime session:

```markdown
{
  "browser_session": "browser-017",
  "computer_session": "agent-desktop-04",
  "agent": "al-jazari",
  "task": "argyris-report-export",
  "profile": "/run/user/.../profiles/browser-017",
  "cdp_endpoint": "http://127.0.0.1:9327",
  "process_id": 42881
}
```

This prevents agents from attaching to your personal browser or another agent’s browser.

## 2\. Per-agent disposable profiles

Each run should get:

- separate cookies;
- local storage;
- IndexedDB;
- cache;
- service workers;
- downloads directory;
- permissions;
- browser history;
- extensions.

Profiles should support:

```markdown
new
snapshot
clone
reset
destroy
```

A reusable authenticated profile may be allowed for specific trusted tasks, but personal Chrome profiles should never be the default.

## 3\. Unified browser event capture

Capture continuously:

```markdown
console
page errors
network requests/responses
failed requests
WebSocket events
downloads
dialogs
navigation
DOM mutations
storage changes
service-worker activity
performance timings
```

After every meaningful action, write only the delta.

```markdown
{
  "action_id": "act-42",
  "navigation": null,
  "console_delta": [],
  "network_delta": [
    {
      "method": "POST",
      "url": "/api/reports",
      "status": 500
    }
  ],
  "dom_state_hash_before": "...",
  "dom_state_hash_after": "..."
}
```

Your current skill already insists that a visually rendered page is insufficient evidence when API, CORS, WebSocket, auth, or provenance requests may be failing.

SKILL

## 4\. Semantic page state

`page_info()` should evolve into a structured observation:

```markdown
{
  "url": "http://localhost:5173/reports",
  "title": "Argyris",
  "viewport": [1440, 900],
  "focused_element": {
    "role": "textbox",
    "name": "Ask Argyris"
  },
  "interactive_elements": [],
  "dialogs": [],
  "loading": false,
  "console_errors": 0,
  "failed_required_requests": 0,
  "state_hash": "..."
}
```

Include:

- DOM;
- accessibility tree;
- visible text;
- active element;
- dialogs;
- form state;
- route;
- application-specific state where available.

## 5\. Event-driven waits

Instead of fixed sleeps:

```markdown
wait_for_load()
sleep(3)
```

Support:

```markdown
wait_for_url
wait_for_selector
wait_for_dom_stable
wait_for_network_idle
wait_for_request
wait_for_response
wait_for_download
wait_for_console_error
wait_for_websocket_message
wait_for_application_state
```

For simulation dashboards:

```markdown
click "Run"
→ wait for POST /jobs
→ record job ID
→ wait for WebSocket state=completed
→ inspect rendered result
```

## 6\. Browser-use hooks

The Python library already provides the right place to introduce lifecycle hooks. Standardize them:

```markdown
on_browser_start
on_page_open
before_action
after_action
on_navigation
on_console_event
on_network_event
on_download
on_dialog
on_failure
on_browser_stop
```

All hooks should emit the same runtime trace schema used by Hyprland and shell actions.

## 7\. Application-aware browser adapters

Generic DOM interaction is useful, but your own applications can expose richer information.

For Argyris:

```markdown
current case ID
evidence bundle status
report compilation state
unbound claims
export eligibility
agent conversation ID
```

For Masnaa OS:

```markdown
selected factory object
source freshness
synthetic/live status
approval state
active evidence bindings
```

Expose these through a safe debug/test bridge:

```markdown
window.__ASAYL_TEST_STATE__
```

or a local test endpoint.

Then browser-use can inspect actual product state rather than infer everything from pixels.

## Browser-use and Playwright have different jobs

Do not collapse them into one tool.

## Browser-use

Best for:

```markdown
exploration
goal-directed navigation
unknown applications
visual inspection
adaptive recovery
research
finding workflows
discovering bugs
```

## Playwright

Best for:

```markdown
exact replay
stable regression tests
assertions
trace artifacts
browser matrices
network fixtures
fail-before / pass-after verification
```

The desired loop is:

```markdown
browser-use discovers a workflow or failure
→ runtime stores semantic action trace
→ compiler creates Playwright repro
→ Playwright confirms failure
→ agent patches code
→ Playwright confirms repair
→ browser-use explores nearby behavior
```

## Integrating browser-use with Hyprland

A single task can combine both:

```markdown
1. Runtime creates isolated worktree.
2. Runtime starts development server.
3. Runtime starts nested Hyprland only if needed.
4. Chromium starts with unique profile and CDP endpoint.
5. Hyprland registers browser window ownership.
6. Browser-use controls tabs, DOM, network and console.
7. Hyprland handles file picker or external application.
8. Browser-use resumes page control.
9. Playwright verifies the final scenario.
10. Runtime destroys browser, desktop and services.
```

## Channel handoff example

Uploading a solver result:

```markdown
browser-use:
  click Upload

OS file chooser appears

Hyprland/AT-SPI:
  detect dialog
  select synthetic solver file
  confirm

browser-use:
  wait for upload request
  inspect response
  verify parsed case appears
```

Neither browser-use nor Hyprland alone is ideal for the entire flow. The runtime routes each step to the strongest channel.

## Browser-specific isolation

Each browser session should run in a systemd scope:

```markdown
agent-browser@017.scope
```

With:

- CPU quota;
- memory limit;
- process limit;
- temporary profile;
- dedicated downloads;
- allowed localhost ports;
- network restrictions when appropriate;
- no access to personal browser data;
- automatic process cleanup.

Possible session manifest:

```markdown
browser:
  engine: chromium
  profile: ephemeral
  headed: true
  cdp: enabled
  downloads: isolated
  network:
    allow:
      - localhost
      - docs.python.org
    deny_private_networks: true
  limits:
    memory: 3GiB
    cpu: 200%
    max_tabs: 8
```

## Browser observability UI

In your main Hyprland session, build a small supervisor surface:

```markdown
Agent browsers
├── browser-01 · Argyris · 2 tabs · healthy
├── browser-02 · Masnaa OS · 1 failed request
└── browser-03 · research · waiting for approval
```

Actions:

```markdown
watch
pause
take over
open trace
inspect console
inspect network
kill
```

A browser can run headless normally, then become visible inside a nested desktop when you want to inspect it.

## Revised skill architecture

```markdown
computer-runtime
├── browser-use
│   ├── exploratory operator
│   ├── CDP diagnostics
│   ├── session management
│   └── browser event capture
│
├── playwright
│   ├── deterministic replay
│   ├── regression tests
│   └── trace verification
│
├── hyprland-computer-use
│   ├── desktop/window lifecycle
│   ├── nested sessions
│   ├── OS dialogs
│   ├── accessibility
│   └── pixel fallback
│
├── process-runtime
│   ├── services
│   ├── PTYs
│   └── resource monitoring
│
└── evidence-runtime
    ├── unified action trace
    ├── artifacts
    └── receipts
```

## First combined vertical slice

The best first demonstration is a real coding loop:

```markdown
create isolated worktree
→ start local web application
→ start isolated Chromium
→ browser-use opens and explores application
→ observe console and network
→ Codex modifies source
→ browser automatically reloads
→ browser-use verifies visible behavior
→ Playwright compiles and replays the scenario
→ final screenshot + trace + tests retained
→ session cleaned up
```

Success gate:

```markdown
- no interaction with your personal browser;
- no interaction with your host Hyprland windows;
- browser console and network captured;
- source modification verified in the real app;
- Playwright replay succeeds from a fresh profile;
- all created processes and profiles are removed;
- receipt identifies every command, action and artifact.
```

So the corrected priority is:

```markdown
P0: Browser-use + Playwright integrated into the runtime
P0: Nested Hyprland for cross-application workflows
P1: AT-SPI semantic native-app control
P1: Unified tracing and replay
P2: Multiple concurrent agent desktops
```

**Most software development work should remain browser-first.** Hyprland expands the agent beyond the browser; it does not replace the browser-use system.

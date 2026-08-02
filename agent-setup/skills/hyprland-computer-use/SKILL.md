---
name: hyprland-computer-use
description: Use to visually see, screenshot, and drive GUI apps on this Hyprland/Wayland desktop — capture a window or the screen, click at coordinates, type, target windows, and run apps offscreen for non-intrusive visual testing. Reusable across any app (Electron/VSCodium/wlroots). Use when you need to SEE what an app renders, verify a GUI change visually, or automate a desktop interaction that has no API/CDP path.
---

# Hyprland computer-use toolkit

A small, reusable toolkit for seeing and driving GUI apps on this Hyprland
(wlroots) desktop. Built on the tools this machine already has — `grim`,
`hyprctl`, `wlrctl`, `wtype`, `cage` — with the coordinate/window plumbing that
Wayland deliberately does not provide globally.

**Scripts live in `bin/` (add to PATH or call directly):**

| script | does |
|---|---|
| `hcu-capture` | screenshot the focused monitor / a window / a region → PNG + geometry |
| `hcu-window`  | list / geo / focus / active — discover windows and their pixel geometry |
| `hcu-click`   | click at an absolute desktop pixel (`hcu-move` = move only) |
| `hcu-type`    | type text / press keys into the focused window (safe-chunked — see below) |
| `hcu-offscreen` | run any app in a headless `cage` and screenshot it — nothing on the live desktop |

## When to use which oracle (important)

Prefer the most deterministic path that can see what you need:

1. **The app has an API / CDP / test hook** (e.g. a VS Code extension → CDP via
   `vscode-test-playwright`, a web app → Playwright): use THAT. DOM/state
   assertions are deterministic; screenshots are not. Do not reach for pixels
   when a DOM is available.
2. **You need to verify VISUAL rendering** (layout, does-it-look-right, a native
   dialog, a non-DOM surface): screenshot with `hcu-capture` (or `hcu-offscreen`
   for an app you don't want on the live desktop) and READ the PNG.
3. **You must drive a native GUI with no API** (OS dialogs, window-manager
   behavior, an app that exposes nothing): the capture → click/type → re-capture
   loop below.

## The loop (screenshot → act → verify)

```
1. hcu-window geo <app>              # get the window's origin (x,y) and size
2. hcu-capture window <app>          # PNG of just that window; READ it
3. locate the target in the image    # a button at image-pixel (bx,by)
4. hcu-click $((wx+bx)) $((wy+by))   # window origin + in-window offset = desktop pixel
5. hcu-capture window <app>          # re-capture and READ — confirm the state changed
```

Always **re-capture and verify** after an action — never assume a click worked
(the single most common computer-use failure mode).

## Coordinates & HiDPI

- `hcu-capture` prints `<out> <x>,<y> <w>x<h> scale=<s>`. The `x,y,w,h` are real
  desktop pixels; `scale` is the monitor's HiDPI scale.
- If you downscale a screenshot for a vision model (recommended: ~1024px wide),
  map the model's point back: `real = model * (capture_w / small_w)`, then add the
  window origin for a windowed capture.
- `hcu-capture` reports monitor size in LOGICAL pixels (already `/scale`), so
  clicks computed from a logical-pixel capture need no extra scale factor.

## Offscreen (non-intrusive) testing

`hcu-offscreen` runs an app in a headless `cage` compositor on an isolated
`XDG_RUNTIME_DIR`, so it never touches the live Hyprland session, then grabs a
PNG. Use it to visually test an Electron/VSCodium/wlroots app in a script or CI:

```
WAIT=14 hcu-offscreen /tmp/app.png -- codium \
  --ozone-platform=wayland --disable-gpu --disable-workspace-trust \
  --extensionDevelopmentPath=<ext> <workspace>
```

Electron needs `--ozone-platform=wayland --disable-gpu` (the `--disable-gpu`
avoids a headless DMABUF black-frame). Input automation (`hcu-click`) does NOT
reach inside cage (cage isn't Hyprland) — drive offscreen apps by their API/CDP,
or run them on the live session when you must click them.

## Typing: `wtype` corrupts long strings (verified 2026-07-28)

**Do not call `wtype` directly for text — use `hcu-type`.**

Raw `wtype` silently mistypes from roughly the 14th character onward: characters
needing Shift resolve to the wrong key (usually Tab), and it still exits 0, so
the caller sees success.

```
wtype "ABCDEFGHIJKLMNOPQRSTUVWXYZ"   -> ABCDEFGHIJKLM<TAB>PQRSTUVWXYZ
wtype 'a!@#$%^&*()_+{}|:"<>?'        -> a!@#$%^&*()_+<TAB>|:"<>?
```

It is not a timing race (`-d` does not help), and it is **not** about distinct
characters — 36 distinct lowercase+digits type cleanly while 14 uppercase do
not. It reproduces identically on the live desktop and in nested compositors.

`hcu-type` works around it by splitting text into ≤13-character `wtype` calls,
so no call reaches the corrupting position. It also emits leading `-` as key
presses, because `wtype` has no option terminator and silently types nothing for
an argument starting with a dash.

```
hcu-type "long text with symbols!"     # safe by default (chunked)
hcu-type --strategy perchar "..."      # slowest, also clean
hcu-type --strategy paste "..."        # clipboard route — see caveat below
hcu-type -k Return                     # key presses pass straight through
hcu-type -- "--looks-like-a-flag"      # -- ends hcu-type's own option parsing
```

`--strategy paste` skips the virtual keyboard, but it is **not** universally
safer: it depends on the target app's paste binding (a terminal may forward
Ctrl+Shift+V as an escape sequence rather than pasting) and it briefly puts the
text on the clipboard. Use it only when you know the target's binding.

Because the corruption is silent, **verify text landed** wherever a read-back
channel exists (file contents, DOM, `hcu-capture` + read) rather than trusting
the exit code.

Regression test: `~/projects/computer_use/test/test-hcu-type.sh`.

## Constraints (Wayland reality — design around these)

- **No global input injection by design.** `hcu-click` uses Hyprland's own
  `movecursor` + `wlrctl`'s virtual-pointer; `wtype` types into the focused
  window only. There is no X11-style "click anywhere by coordinate" primitive —
  window focus + geometry is how you aim.
- **Tools report success they did not achieve.** `wtype` exits 0 while
  mistyping (see above); a click "succeeds" whether or not anything received it.
  Treat exit codes as "the call ran", never as "the effect happened".
- **`grim` needs `wlr-screencopy`** — works on Hyprland/cage/sway/labwc, NOT on
  weston/mutter/KWin (they need their own capture path).
- Clicking/typing acts on the LIVE desktop — it moves the real cursor and can
  disturb the user. Prefer offscreen or API paths; when driving the live session,
  be deliberate and re-capture to verify.

## Setup on this machine

Installed: `grim`, `slurp`, `hyprctl`, `wtype`, `wlrctl`, `cage` (all present).
Optional: ImageMagick (`magick`) for the `DOWNSCALE=` option in `hcu-capture`.
`ydotool` is intentionally NOT used (needs `/dev/uinput` + a privileged daemon);
`wlrctl` covers pointer/keyboard unprivileged.

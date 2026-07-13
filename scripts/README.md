# scripts/

Curated, deduplicated copies of standalone desktop/dev-box utility scripts
from the source machine's `~/.local/bin` (~290 entries there; this is the
subset judged generic/portable -- see the export report for the full
include/exclude breakdown). Executable bit is preserved. Copy these to
`~/.local/bin` (or anywhere on `PATH`) if you want the Hyprland/waybar
keybindings that call them by name to work.

Several config files reference some of these by **absolute path**
(`/home/elwalid/.local/bin/...` in `bindings.conf`) rather than by `PATH`
lookup -- if you don't keep the username `elwalid` and the `~/.local/bin`
location, grep `home-manager/files/hypr/bindings.conf` for `/home/elwalid`
and update those binds.

## Hyprland / Hyprshell helpers

- `hypr-close-window.sh` -- close the focused window, pushing it onto an
  undo stack (`~/.cache/hypr-closed-windows.stack`).
- `hypr-restore-window.sh` -- reopen the last window closed by
  `hypr-close-window.sh`.
- `hypr-zoom` -- macOS-style compositor zoom in/out/reset/set, anchored to
  the cursor.
- `hyprland-session-shutdown` -- clean session shutdown helper.
- `hyprsession` -- window-layout save/restore session manager for Hyprland.
- `hyprshell-display-resume` -- restore display output + Hyprshell state
  after suspend/DPMS off.
- `hyprshell-fix`, `hyprshell-watchdog` -- Hyprshell recovery/health-check
  helpers.
- `hyprshell-keybind` -- Hyprshell keybind helper.
- `hyprshell-panic` -- force-kill a blocked Hyprshell (bound to
  Super+Ctrl+Delete / Ctrl+Alt+Delete as an escape hatch).
- `hz60`, `hz75` -- force the focused monitor to 1920x1080@60 or @74.97.
- `session-unfreeze` -- recovery script: kills stuck walker/satty processes
  and opens a terminal if Hyprland input/focus gets wedged. Assumes UID
  1000 (default first-user UID on most single-user installs).
- `walker-launch-reset` -- reset/restart the Walker app launcher.
- `xdg-terminal-exec` -- upstream `xdg-terminal-exec` reference
  implementation (resolves the user's preferred terminal for
  `xdg-terminal-exec`-aware launchers).

## Audio / input / activitywatch

- `audio-check`, `audio-fix` -- diagnose/restart PipeWire & WirePlumber
  audio when it gets stuck.
- `awatcher-wayland` -- Nix-path wrapper for the `awatcher` ActivityWatch
  Wayland window watcher.
- `aw-input-tracker.py` -- optional keyboard/mouse input-activity tracker
  feeding ActivityWatch.
- `aw-quick-ref.sh` -- prints a quick reference for the ActivityWatch
  scripts and where the daily vault files live.
- `aw-save-today.sh` -- manual trigger to snapshot today's ActivityWatch
  stats (calls `aw-to-vault.py today`).
- `aw-to-vault.py` -- queries the ActivityWatch API and writes a daily
  markdown summary to `~/Documents/vault_elwalid/daily/` (rename that
  folder to taste, e.g. `vault_<yourname>`, or edit `VAULT_PATH` in the
  script).
- `aw-watchdog.sh` -- restarts ActivityWatch services if they've died.
- `setup-input-tracking.sh` -- one-time setup for the input-activity
  tracker above.
- `btop` -- NixOS wrapper for `btop` that fixes `LD_LIBRARY_PATH` so the
  NVIDIA/NVML GPU panel works.
- `dictate-local`, `dictate-local-setup` -- fully local push-to-talk
  dictation via `whisper.cpp`: records mic audio, transcribes, copies text
  to clipboard. `-setup` downloads the base English ggml model.
- `voxtype` -- wrapper that prefers a real installed `voxtype` binary and
  falls back to `dictate-local` if it isn't built yet.
- `notify-rich` -- small `notify-send` wrapper with per-app icon/name
  presets (Codex, Ghostty, Omarchy).
- `parity-health` -- quick health check for the desktop shell: counts
  waybar/elephant/walker processes and checks critical Hyprland keybinds
  are present.
- `postboot-check` -- post-login sanity check: display resolution/fallback
  mode, waybar process count, and a specific TP-Link/Realtek USB Wi-Fi
  dongle's USB mode (vendor/product IDs `0bda:1a2b`/`0bda:c811` -- see
  `wifi-fix` below and `tpLinkWifiModeswitch` in
  `nixos/configuration.nix`; adjust or remove if you don't have this
  dongle).
- `wifi` -- opens `nm-connection-editor` (or `nmtui` in a terminal) for
  Wi-Fi setup.
- `extract-archive` -- extract any archive format (tar.*, zip, rar, 7z...)
  into a sibling directory, with a desktop notification when done.
- `nautilus` -- NixOS wrapper for Nautilus that fixes GIO/GVfs module
  loading; falls back to `xdg-open` if Nautilus isn't installed.
- `sioyek-agent`, `sioyek-note` -- Sioyek PDF-reader plugins: send
  selected text to a local Ollama model or an OpenAI-compatible API (via
  the `OPENAI_API_KEY` env var, never hardcoded) for an explanation, or
  append selected text as a timestamped note, both appended to a markdown
  file next to the PDF.
- `terminaltexteffects`, `tte` -- thin wrappers around the
  `terminaltexteffects` CLI (installed via the user's Nix profile).
- `llama-local` -- run a local GGUF model through `llama.cpp` with sane
  defaults (context size, GPU layers, temperature); configurable via
  `LLAMA_CPP_*` env vars. Pairs with the `llama-cpp` (Vulkan) package in
  `nixos/configuration.nix`.
- `llm` -- thin one-shot prompt wrapper around `llama-local` that strips
  the model's echo/banner noise from the output.
- `zs` -- small Zellij session picker/attacher (`zs`, `zs <name>`,
  `zs -l`, `zs -k <name>`).
- `uwsm`, `uwsm-app` -- minimal compatibility shims providing `uwsm app --
  <cmd>` / `uwsm-app -- <cmd>` semantics, used heavily by the shipped
  Hyprland config's `exec-once`/keybind lines. NixOS's own `uwsm` package
  (`programs.uwsm.enable = true` in configuration.nix) should normally
  provide these; these shims are a fallback if that binary isn't on PATH
  yet.

## omanix-\* / omarchy-\*

These are the desktop-shell helper scripts for the
[omanix](https://github.com/T00fy/omanix) Hyprland module (`omanix.enable
= true;` in `nixos/configuration.nix`), used by the launcher menu, window
rules, waybar, and keybindings. Most have a matching `omanix-*` (current)
and `omarchy-*` (legacy/compat) name doing the same thing, e.g.
`omanix-launch-audio` / `omarchy-launch-audio`,
`omanix-toggle-idle` / `omarchy-toggle-idle`. Both are included for
compatibility since both prefixes are referenced across the config. A
short description of what each *category* does:

- `*-cmd-*` (`omanix-cmd-audio-switch`, `omarchy-cmd-screenshot`,
  `*-cmd-terminal-cwd`, `*-cmd-logout/reboot/shutdown`, `*-cmd-share`,
  `omarchy-cmd`, `omarchy-cmd-first-run`) -- small single-purpose command
  helpers invoked from the menu/keybindings (screenshot, screen share,
  audio-device switch, power actions, "what directory is my terminal in").
- `*-launch-*` (`*-launch-audio`, `*-launch-bluetooth`, `*-launch-browser`,
  `*-launch-editor`, `*-launch-or-focus[-tui]`, `*-launch-tui`,
  `*-launch-walker`, `*-launch-webapp[-or-focus]`, `*-launch-wifi`,
  `*-launch-screensaver`) -- open an app, or focus it if it's already
  running; `-tui` variants wrap terminal apps (btop, lazydocker, etc.) in
  a floating terminal.
- `*-hyprland-*` (`*-hyprland-window-close-all`, `*-hyprland-window-pop`,
  `*-hyprland-workspace-toggle-gaps`,
  `omarchy-hyprland-monitor-scaling-toggle`,
  `omarchy-hyprland-window-single-square-aspect-toggle`) -- window/
  workspace manipulation helpers used by keybindings.
- `*-menu*` (`omanix-menu`, `omarchy-menu`, `*-menu-style`,
  `*-menu-keybindings`) -- the Omarchy-style launcher menu (Super+Space)
  and its style/keybindings sub-menus.
- `*-theme-*` (`omarchy-theme-set`, `omarchy-theme-set-zed`,
  `omarchy-theme-repair`, `omanix-theme-bg-next`,
  `omarchy-toggle-nightlight`) -- theme/wallpaper switching and repair.
- `*-toggle-*` (`*-toggle-idle`, `*-toggle-waybar`,
  `omarchy-toggle-notification-silencing`) -- idle-inhibit, waybar
  visibility, and notification-silencing toggles.
- `omanix-lock-screen` / `omarchy-lock-screen`,
  `omanix-screensaver` / `omarchy-launch-screensaver` -- screen lock and
  screensaver launch (used by `hypridle.conf`).
- `omanix-restart-walker`, `omanix-smart-delete`, `omanix-workspace` --
  restart the Walker launcher service, a "move to trash instead of rm"
  helper, and workspace helper.
- `omarchy-battery-remaining`, `omarchy-brightness-display[-apple]`,
  `omarchy-brightness-keyboard` -- battery estimate and
  screen/keyboard-backlight brightness controls.
- `omarchy-start-shell-ui`, `omarchy-ui-restart` -- (re)start the desktop
  shell UI (waybar/swaybg) as user services.
- `omarchy-nix-flake-update-switch`, `omarchy-nix-gc`,
  `omarchy-nix-git-commit`, `omarchy-nix-pkg-install`,
  `omarchy-nix-rebuild-switch`, `omarchy-nix-rebuild-test` -- convenience
  wrappers around `nix flake update`, `nix-collect-garbage`, committing
  `/etc/nixos` (assumes your flake lives at `/etc/nixos`, matching the
  install steps in the top-level README), and `nixos-rebuild
  switch/test/build`. `omarchy-nix-pkg-install` and `-show-setup-help` /
  `-show-style-help` print/install helper info.
- `omanix-show-setup-help`, `omanix-show-style-help` -- print setup/theming
  help text.

## Deliberately excluded (see export report for the full list + reasons)

Not copied here: personal AI-tool CLIs and account managers (`codex-*`,
`oc-*`/`opencode-*`, `ai-credits*`, `chatgpt`, `grok`, `agent-run`, `agy`,
`browser-use`, `clawpatch`, `ncode*`), personal note/knowledge-base tools
(`pkos`, `sb`, `daily-digest-*`, `dailylog-*`), personal cloud/ML project
scripts (`modal-*`, `kaggle-preflight`, `migration-freeze-snapshot`),
`construct`/`yt-dlp` (large bundled binaries, not scripts), assorted
uv/npm/nix-profile-installed tool symlinks (`kaggle`, `openhands*`,
`oracle*`, `zed`, `python3.12`, etc. -- install those yourself via
`uv tool install` / `npm i -g` / your Nix profile), and `wifi-fix` (hardcodes
this machine's home Wi-Fi SSID names and a person's name -- flagged for
human review rather than shared as-is).

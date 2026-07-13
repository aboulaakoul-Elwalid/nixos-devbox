# Installing this repo — instructions for an AI coding agent

You are being run inside a freshly cloned copy of this repo, on a **different
machine** than the one it was exported from (source user: `elwalid`). Your
job is to help whoever is running you turn this repo into a working NixOS +
Hyprland system on *their* hardware, under *their* username — not to
reproduce the source machine byte-for-byte.

Read this file first. It's the orchestration layer over four sub-READMEs
that each cover one piece in detail: `nixos/README.md`, `scripts/README.md`,
`agent-setup/README.md`, and the doc comments inside
`home-manager/modules/*.nix`. Read those as you get to each step below —
this file tells you the order and what to ask the human; the sub-READMEs
have the exact commands and full list of what to edit.

## Before you touch anything: ask these questions

Don't guess at any of these — ask the human running you, up front, before
editing files:

1. **Username and hostname** they want on this machine. Must be applied
   consistently across `nixos/configuration.nix` (`users.users.<name>`),
   `nixos/flake.nix` (`home-manager.users.<name>` attribute), and
   `home-manager/home.nix` (`home.username` / `home.homeDirectory`) — see
   `nixos/README.md` steps 4–5 for the exact spots.
2. **Disk encryption.** The shipped config assumes LUKS (`boot.initrd.luks.devices` in
   `nixos/configuration.nix`). Ask whether they want disk encryption at all —
   if not, that whole block should be deleted, not just have its UUID swapped.
3. **Extra data drive.** `fileSystems."/mnt/hdd"` and the `services.udev.extraRules`
   UUID allow-list are specific to a second NTFS drive on the source machine.
   Ask if they have anything similar; if not, delete both blocks.
4. **The `keyd` keyboard remap** in `nixos/configuration.nix` swaps Q/A,
   W/Z, and `;`/M — this is elwalid's personal muscle-memory layout, almost
   certainly *not* wanted by anyone else. Ask before keeping it; default to
   removing it if they're unsure.
5. **Git identity.** `home-manager/files/git/config` has elwalid's `[user]
   name`/`email` hardcoded. Ask for theirs and update that file (or tell them
   to run `git config --global user.name/user.email` after and just delete
   the `[user]` block here).
6. **Starting theme.** `gruvbox` is what's active by default (see
   `home-manager/modules/theme.nix`). That's just a starting point — mention
   they can switch anytime post-install with the `omarchy-theme-set` /
   `omanix-theme-bg-next` scripts in `scripts/`, no need to pick now unless
   they already know they want something else.

If the human says "just use sensible defaults, don't ask me a bunch of
questions" — then: keep their own username/hostname (ask only that one),
drop the LUKS block only if they confirm no encryption, drop `/mnt/hdd` and
the keyd remap by default (they're the two most obviously source-machine-only
pieces), and leave everything else as shipped.

## Order of operations

This assumes NixOS is already installed and booted (bare, no desktop yet) —
that has to happen before this repo is even relevant; if it isn't done yet,
tell the human to do a normal `nixos-install` first and come back once
they've rebooted into a working networked system.

1. **Regenerate hardware config.** Run
   `sudo nixos-generate-config --show-hardware-config > nixos/hardware-configuration.nix`
   from inside the cloned repo. Never keep the shipped one — it's this
   exact source machine's disk UUIDs and will not boot on different hardware.
2. **Edit `nixos/configuration.nix`** per the questions above and per the
   full checklist in `nixos/README.md` (hostname, user block, LUKS,
   `/mnt/hdd`, udev rules, keyd, the `tpLinkWifiModeswitch` service — that
   last one is harmless to leave, it no-ops if the specific USB device isn't
   present).
3. **Edit `nixos/flake.nix`** if the username changed — the
   `home-manager.users.elwalid` attribute name must match.
4. **Edit `home-manager/home.nix`** — `home.username` / `home.homeDirectory`.
5. **Edit `home-manager/files/git/config`** — `[user]` block.
6. **Rebuild:** `sudo nixos-rebuild switch --flake ./nixos#nixos` (or copy
   `nixos/` + `home-manager/` into `/etc/nixos` first if they'd rather keep
   this repo separate from `/etc/nixos` long-term — see `nixos/README.md`
   for both options, they're equivalent).
7. **Reboot.** They should land in Hyprland with waybar, the current theme,
   and all the config from step 2–5 applied.
8. **Scripts:** copy `scripts/` to `~/.local/bin` (or wherever their `PATH`
   points) so the Hyprland/waybar keybindings that shell out to these
   scripts actually work. See `scripts/README.md` for what each one does.
9. **Agent setup (optional, ask first):** only if they want elwalid's Claude
   Code / OpenCode / Codex configuration too, follow `agent-setup/README.md`.
   This is unrelated to the desktop and shouldn't be assumed.

## Guardrails

- This is someone else's machine. Confirm before any destructive step —
  partitioning, `nixos-rebuild switch` (it's reversible via the bootloader's
  previous-generation entry, but still confirm), anything touching
  `/mnt/hdd`-style mount points if they said they *do* have a similar drive.
- If something in `nixos/configuration.nix` clearly won't apply to their
  hardware (different GPU vendor, no LUKS, different drive layout) and
  they haven't told you what to do about it yet — ask, don't guess and
  don't silently delete it either.
- No credentials, tokens, or accounts are anywhere in this repo. Do not
  invent placeholder secrets or try to "restore" any account state — the
  human authenticates GitHub/Claude/1Password/etc. themselves, normally,
  after the system is up.
- If a build or rebuild fails, read the actual Nix error before proposing a
  fix — most likely causes are: a step above was skipped (hardware config
  not regenerated, username mismatch between the three files in step 2–4
  above), or a genuinely different piece of hardware needing an option this
  config doesn't have (e.g. an AMD GPU instead of the shipped
  `hardware.nvidia` block).

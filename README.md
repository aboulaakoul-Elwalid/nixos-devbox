# nixos-devbox-export

A self-contained snapshot of a NixOS + Hyprland (via the
[omanix](https://github.com/T00fy/omanix) module) desktop/dev-box setup,
packaged so someone else can reproduce the same system, desktop, and shell
experience on their own hardware.

This repo was exported from a single personal machine. It is **not** a
generic NixOS starter kit -- some parts (disk layout, LUKS UUIDs, one extra
data drive, a keyboard remap, a Wi-Fi USB dongle mode-switch) are specific to
that machine and are called out explicitly below so you can replace or drop
them.

No credentials, tokens, browser profiles, or password-manager data are
included anywhere in this repo. You will sign into your own accounts
(GitHub, 1Password, etc.) after rebuilding. See "Redactions" at the bottom
for the one thing that was found and scrubbed during export.

## What's in here

```
nixos/            NixOS system configuration (flake, configuration.nix,
                   hardware-configuration.nix -- THIS MACHINE'S hardware,
                   see below)
home-manager/      Home Manager configuration that reproduces the Hyprland
                   desktop, waybar, terminals, shell, and git config
scripts/           Curated standalone desktop/dev-box utility scripts
                   (~/.local/bin on the source machine), with a README
                   describing each one
```

## Install steps

1. **Install NixOS normally** on your own disk (standard NixOS installer /
   minimal ISO). Get to a working, booted NixOS system with networking, on
   any user, before touching this repo.

2. **Clone this repo** onto that machine, e.g.:
   ```
   git clone <this-repo-url> ~/nixos-devbox-export
   ```

3. **Regenerate your own hardware config.** The shipped
   `nixos/hardware-configuration.nix` is copied verbatim from the source
   machine: its LUKS device UUIDs, disk-by-UUID paths, and swap device are
   specific to that one machine's disks and **will not work on different
   hardware** (it will likely fail to boot). Run:
   ```
   sudo nixos-generate-config --show-hardware-config > ~/nixos-devbox-export/nixos/hardware-configuration.nix
   ```
   This overwrites the placeholder with your own machine's real hardware
   config.

4. **Edit `nixos/configuration.nix`.** Things you must change or remove:
   - `networking.hostName` -- currently `"nixos"`.
   - The `users.users.elwalid` block -- rename to your own username and
     `description`. Home Manager's username (step 5) and the
     `home-manager.users.<name>` wiring in `nixos/flake.nix` must match
     whatever you pick here.
   - `boot.initrd.luks.devices."luks-1f8ba60f-0725-4a15-8c91-f894c75ec492"` --
     this machine's LUKS root device UUID. Your regenerated
     `hardware-configuration.nix` (step 3) will already have the right UUID
     for your own disk; delete/replace this block in `configuration.nix` to
     match (or remove it entirely if you don't use LUKS).
   - `fileSystems."/mnt/hdd"` -- an extra NTFS data drive mounted on the
     source machine only. Remove this block unless you have the same drive
     (same `by-uuid` device).
   - `services.udev.extraRules` -- a UUID allow-list telling udisks2 to
     ignore specific block devices (recovery partitions, that same extra
     drive, etc.) on the source machine. Remove or replace the UUIDs with
     your own, or drop the block entirely.
   - `services.keyd` -- elwalid's personal QWERTY key remap (swaps
     Q/A, W/Z, `;`/M). Remove this block if you don't want it.
   - `systemd.services.tpLinkWifiModeswitch` -- a fallback USB mode-switch
     for a specific Realtek `0bda:1a2b` Wi-Fi dongle on the source machine.
     Harmless to leave in (it's a no-op if that USB device ID never shows
     up), but remove it if you don't have that dongle.
   - Everything else (packages, Hyprland, NVIDIA driver config, Docker,
     fonts, power management, etc.) is generic and should work as-is,
     modulo normal package-availability drift over time.

5. **Edit `home-manager/home.nix`.** Set `home.username` and
   `home.homeDirectory` to your own (they default to `elwalid` /
   `/home/elwalid` with a `# CHANGE THIS` comment). These must match the
   username you set in step 4.

6. **Wire Home Manager into the system config and rebuild.**
   `nixos/flake.nix` already imports the `home-manager` NixOS module and
   points `home-manager.users.elwalid` at `../home-manager/home.nix` -- if
   you renamed the user in step 4, update that attribute name too. Then
   copy both `nixos/` and `home-manager/` onto the target system, e.g.
   straight into `/etc/nixos` so the relative path resolves:
   ```
   sudo cp -r ~/nixos-devbox-export/nixos/. /etc/nixos/
   sudo cp -r ~/nixos-devbox-export/home-manager /etc/nixos/home-manager
   sudo nixos-rebuild switch --flake /etc/nixos#nixos
   ```
   (You can instead run `nixos-rebuild switch --flake ~/nixos-devbox-export/nixos#nixos`
   directly from the cloned repo without copying anything -- Nix resolves
   the `../home-manager/home.nix` relative import against the git
   repository root, which is `~/nixos-devbox-export`, so it works either
   way as long as the whole repo stays one git checkout.)

7. **Curated scripts.** Copy `scripts/` to `~/.local/bin` (or anywhere on
   your `PATH`) if you want the desktop helper scripts referenced by the
   Hyprland/waybar config (window-close/restore, Hyprshell helpers, zoom,
   dictation, audio fixes, omanix/omarchy launcher helpers, etc.):
   ```
   mkdir -p ~/.local/bin
   cp ~/nixos-devbox-export/scripts/* ~/.local/bin/
   ```
   See `scripts/README.md` for what each one does and which config files
   reference them by absolute path.

## What you'll still need to do yourself

- Sign into GitHub (`gh auth login`), 1Password, Bitwarden, Signal, Spotify,
  etc. -- no accounts, sessions, or credentials are included.
- If you want Oh My Zsh / Powerlevel10k parity, install Oh My Zsh yourself
  (`.zshrc` sources it only if `~/.oh-my-zsh/oh-my-zsh.sh` exists -- it's
  skipped gracefully otherwise). `atuin` shell history is likewise optional
  and only activated if the `atuin` binary is present.
- A handful of scripts reference personal AI-tool CLIs (`opencode`,
  `codex`, `tokscale`, etc.) that are **not** included in this repo (see
  the export report / scripts/README.md for the full exclusion list). The
  Hyprland/waybar config still works without them; a few keybindings
  (OpenCode launcher, AI-credits waybar widget's fine-grained token count,
  session-resume panel) will just no-op or show reduced info.

## Redactions

One embedded secret was found and redacted during export:

- `home-manager/files/zsh/zshrc` (originally `~/.zshrc`), line 773:
  a hardcoded `DISCORD_TOKEN=...` value (a live Discord bot token) was
  replaced with `DISCORD_TOKEN=<SET-YOUR-OWN-VALUE>`. Set your own token
  via environment/local override if you use this, or delete the line.

No other API keys, tokens, passwords, or private-key material were found in
any file copied into this repo. See the export report for the full
redaction methodology and scan commands used.

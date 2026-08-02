# Terminal emulator configuration: Alacritty, Kitty, Ghostty.
#
# All three `import`/`include` an omarchy theme file
# (~/.config/omarchy/current/theme/*.{toml,conf}) -- see modules/theme.nix,
# NOT the omanix module (deliberately not wired into home-manager here, see
# nixos/flake.nix's comment).
{ config, pkgs, lib, ... }:

{
  xdg.configFile = {
    "alacritty/alacritty.toml".source = ../files/alacritty/alacritty.toml;
    "kitty/kitty.conf".source = ../files/kitty/kitty.conf;
    "ghostty/config".source = ../files/ghostty/config;
    # Tells xdg-terminal-exec (scripts/xdg-terminal-exec) which terminal to
    # actually use -- without this it falls back to unstable auto-detection
    # across all installed terminals, and some invocation paths (e.g. one
    # kitty code path) don't handle plain command execution correctly.
    # ghostty here to match $terminal in files/hypr/bindings.conf.
    "xdg-terminals.list".source = ../files/xdg-terminals.list;
  };
}

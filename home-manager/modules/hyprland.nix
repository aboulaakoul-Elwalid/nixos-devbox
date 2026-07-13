# Hyprland desktop configuration.
#
# NOTE: hyprland.conf sources several files under
# ~/.local/share/omarchy/default/hypr/... and ~/.config/omarchy/current/theme/...
# Those come from the `omanix` flake input (see nixos/flake.nix,
# `omanix.enable = true;` in nixos/configuration.nix) -- they are NOT part of
# this repo and are installed automatically by the omanix NixOS module.
{ config, pkgs, lib, ... }:

{
  xdg.configFile = {
    "hypr/autostart.conf".source = ../files/hypr/autostart.conf;
    "hypr/bindings.conf".source = ../files/hypr/bindings.conf;
    "hypr/envs.conf".source = ../files/hypr/envs.conf;
    "hypr/hypr_overrides.conf".source = ../files/hypr/hypr_overrides.conf;
    "hypr/hypridle.conf".source = ../files/hypr/hypridle.conf;
    "hypr/hyprland.conf".source = ../files/hypr/hyprland.conf;
    "hypr/hyprlock.conf".source = ../files/hypr/hyprlock.conf;
    "hypr/hyprsunset.conf".source = ../files/hypr/hyprsunset.conf;
    "hypr/input.conf".source = ../files/hypr/input.conf;
    "hypr/looknfeel.conf".source = ../files/hypr/looknfeel.conf;
    "hypr/monitors.conf".source = ../files/hypr/monitors.conf;
    "hypr/windowrules.conf".source = ../files/hypr/windowrules.conf;
    "hypr/xdph.conf".source = ../files/hypr/xdph.conf;

    # exec-once entries in autostart.conf and bindings.conf call these by
    # absolute path (/home/elwalid/.config/hypr/scripts/...), so they need to
    # be executable and live at this exact path.
    "hypr/scripts/autolaunch.sh" = {
      source = ../files/hypr/scripts/autolaunch.sh;
      executable = true;
    };
    "hypr/scripts/opencode-session-restore.sh" = {
      source = ../files/hypr/scripts/opencode-session-restore.sh;
      executable = true;
    };
    "hypr/scripts/opencode-session-save.sh" = {
      source = ../files/hypr/scripts/opencode-session-save.sh;
      executable = true;
    };
    "hypr/scripts/session-restore.sh" = {
      source = ../files/hypr/scripts/session-restore.sh;
      executable = true;
    };
  };
}

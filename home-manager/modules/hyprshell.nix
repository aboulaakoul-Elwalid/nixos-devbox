# hyprshell (workspace/window switcher, handles SUPER+TAB) refuses to start
# at all without its own config file -- another thing never captured before:
# "Failed to load config: Config file does not exist" -> exits 1 -> systemd
# restart-loops it into start-limit-hit. See hypr/bindings.conf's comment:
# SUPER+TAB is handled from here via ~/.local/bin/hyprshell-keybind.
{ config, pkgs, lib, ... }:

{
  xdg.configFile = {
    "hyprshell/config.toml".source = ../files/hyprshell/config.toml;
    "hyprshell/styles.css".source = ../files/hyprshell/styles.css;
  };
}

# Omarchy theme system: color palettes, wallpapers, and per-app theme files
# (waybar.css, hyprlock.conf, mako.ini, neovim.lua, vscode.json, btop.theme,
# icons) for 18 themes. This is what actually drives the "look":
#   - waybar's style.css does `@import "../omarchy/current/theme/waybar.css"`
#   - hyprlock.conf does `source = ~/.config/omarchy/current/theme/hyprlock.conf`
#     and points its background at `~/.config/omarchy/current/background`
#   - mako's config is a symlink to `~/.config/omarchy/current/theme/mako.ini`
#
# This directory is NOT managed by the `omanix` flake module -- it's plain
# mutable data (theme-switcher scripts like `omarchy-theme-set` /
# `omanix-theme-bg-next`, both in ../scripts/, rewrite `current/` at runtime).
# So it's deployed with `recursive = true` (individual file symlinks, not one
# directory symlink) to leave it writable by those scripts, and the current
# theme (gruvbox, at export time) is the starting default -- switch it anytime
# with the theme-switcher scripts.
{ config, pkgs, lib, ... }:

{
  home.file.".config/omarchy" = {
    source = ../files/omarchy;
    recursive = true;
  };

  # mako's config on the source machine is a symlink into the active theme,
  # not a static file -- recreate that as a real (out-of-store) symlink so it
  # keeps following whichever theme is current, same as the source machine.
  home.file.".config/mako/config".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/omarchy/current/theme/mako.ini";
}

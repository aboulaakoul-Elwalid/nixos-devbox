# The stock upstream Omarchy defaults (github.com/basecamp/omarchy) that
# elwalid's own hyprland.conf sources as its BASE layer, before his own
# overrides in ~/.config/hypr/ on top. On the source machine this lives at
# ~/.local/share/omarchy/ -- a full clone of the upstream Omarchy repo
# (144MB, mostly Arch-specific stuff: pacman mirrorlists, limine bootloader
# configs, plymouth boot splash -- none of which applies on NixOS). This
# module ships only the `default/hypr/` subtree that's actually `source =`'d
# by files/hypr/hyprland.conf; the rest of that upstream repo (waybar
# indicator scripts, walker's default theme, mako's base config, themed/
# templates) is NOT included here -- if something else turns out to need it,
# check ~/.local/share/omarchy/default/ on the source machine for the same
# treatment this module gives hypr/.
{ config, pkgs, lib, ... }:

{
  xdg.dataFile."omarchy/default/hypr" = {
    source = ../files/omarchy-default/hypr;
    recursive = true;
  };
  # mako's active theme config does `include=~/.local/share/omarchy/default/mako/core.ini`
  xdg.dataFile."omarchy/default/mako" = {
    source = ../files/omarchy-default/mako;
    recursive = true;
  };
  # The actual omarchy-* CLI implementations (omarchy-menu, omarchy-theme-set,
  # omarchy-launch-*, etc, ~190 scripts, 860K). scripts/omarchy-menu and
  # several others exec into here -- e.g. `SUPER+SPACE` was silently doing
  # nothing because this whole directory never existed. Some scripts here are
  # Arch-specific (AUR, pacman, limine bootloader) and simply won't work on
  # NixOS -- harmless if unused, same as other excluded-tool references.
  xdg.dataFile."omarchy/bin" = {
    source = ../files/omarchy-default/bin;
    recursive = true;
  };
  # walker's config.toml points theme = "omarchy-default" at this location.
  xdg.dataFile."omarchy/default/walker" = {
    source = ../files/omarchy-default/walker;
    recursive = true;
  };
}

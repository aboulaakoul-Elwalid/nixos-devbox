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
}

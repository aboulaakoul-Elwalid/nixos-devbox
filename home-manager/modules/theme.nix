# Omarchy theme system: color palettes, wallpapers, and per-app theme files
# (waybar.css, hyprlock.conf, mako.ini, neovim.lua, vscode.json, btop.theme,
# icons) for 18 themes. This is what actually drives the "look":
#   - waybar's style.css does `@import "../omarchy/current/theme/waybar.css"`
#   - hyprlock.conf does `source = ~/.config/omarchy/current/theme/hyprlock.conf`
#     and points its background at `~/.config/omarchy/current/background`
#   - mako's config is a symlink to `~/.config/omarchy/current/theme/mako.ini`
#
# `themes/` and `backgrounds/` (the read-only theme library) ARE nix-managed
# below. `current/` deliberately is NOT, and is never put back in
# ../files/omarchy -- it's plain mutable data that omarchy-theme-set /
# omanix-theme-bg-next rewrite at runtime (`ln -sf` for current/background,
# `rsync --delete` for current/theme/*, a plain `echo >` for
# current/theme.name). Nix-managing any of those as symlinks into the store
# causes two distinct failures once a real theme switch happens: the
# `echo >` write hits a read-only store target ("theme.name" case), and
# home-manager's OWN next activation refuses to re-link over a file that's
# since diverged from what it created ("Existing file ... would be
# clobbered" -- hit this for real on Ahmed's machine the first time a theme
# switch ran before a rebuild). So current/ is bootstrapped once, via the
# real omarchy-theme-set script (same code path a manual switch uses, so it
# can't drift from it), only if missing.
{ config, pkgs, lib, ... }:

{
  home.file.".config/omarchy/themes" = {
    source = ../files/omarchy/themes;
    recursive = true;
  };
  home.file.".config/omarchy/backgrounds" = {
    source = ../files/omarchy/backgrounds;
    recursive = true;
  };
  home.file.".config/omarchy/branding" = {
    source = ../files/omarchy/branding;
    recursive = true;
  };
  home.file.".config/omarchy/extensions" = {
    source = ../files/omarchy/extensions;
    recursive = true;
  };
  home.file.".config/omarchy/hooks" = {
    source = ../files/omarchy/hooks;
    recursive = true;
  };

  # mako's config on the source machine is a symlink into the active theme,
  # not a static file -- recreate that as a real (out-of-store) symlink so it
  # keeps following whichever theme is current, same as the source machine.
  home.file.".config/mako/config".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/omarchy/current/theme/mako.ini";

  home.activation.omarchyCurrentThemeBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/omarchy/current/theme.name" ]; then
      run bash -c 'export PATH="$HOME/.local/share/omarchy/bin:$HOME/.local/bin:$PATH"; omarchy-theme-set gruvbox' || true
    fi
  '';
}

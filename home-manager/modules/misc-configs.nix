# Small standalone-app configs that were found missing during a manual,
# one-by-one audit of every ~/.config subdirectory not already covered by
# another module. Excluded from that audit (checked, deliberately left out):
# secrets found in plaintext (cloudflare API token, obs-websocket password,
# rclone Google Drive OAuth token), personal identity (jj), personal file
# paths (gtk-3.0/bookmarks), auto-generated/runtime-only noise (fcitx5
# profiles, ibus/fcitx dbus session files, dconf's binary blob), and config
# for apps no longer actually installed (aether, neofetch -- neofetch was
# removed from nixpkgs; fastfetch is already the replacement in use).
{ config, pkgs, lib, ... }:

{
  home.file.".config/ast-grep" = {
    source = ../files/ast-grep;
    recursive = true;
  };

  home.file.".config/awatcher/config.toml".source = ../files/awatcher/config.toml;

  # fcitx.conf: input-method env vars for Wayland/Hyprland. ssh-agent.conf:
  # points SSH_AUTH_SOCK at gnome-keyring's agent socket.
  home.file.".config/environment.d/fcitx.conf".source = ../files/environment.d/fcitx.conf;
  home.file.".config/environment.d/ssh-agent.conf".source = ../files/environment.d/ssh-agent.conf;

  home.file.".config/fontconfig/fonts.conf".source = ../files/fontconfig/fonts.conf;
  home.file.".config/fontconfig/conf.d/99-local.conf".source = ../files/fontconfig/conf.d/99-local.conf;

  # GTK icon/cursor/font theme (Yaru-blue / DMZ-Black / Roboto) -- affects
  # nautilus, file-choosers, and any other GTK app's look.
  home.file.".config/gtk-3.0/settings.ini".source = ../files/gtk-3.0/settings.ini;
  home.file.".config/gtk-4.0/settings.ini".source = ../files/gtk-4.0/settings.ini;

  home.file.".config/imv/config".source = ../files/imv/config;
  home.file.".config/qalculate/qalc.cfg".source = ../files/qalculate/qalc.cfg;

  # Default $TERMINAL/$EDITOR + omarchy bin PATH + mise activation for the
  # uwsm-managed Hyprland session.
  home.file.".config/uwsm/env".source = ../files/uwsm/env;
  home.file.".config/uwsm/default".source = ../files/uwsm/default;

  home.file.".config/wiremix/wiremix.toml".source = ../files/wiremix/wiremix.toml;

  # Stops audio devices auto-suspending (a real, previously-hit annoyance).
  home.file.".config/wireplumber/wireplumber.conf.d/51-disable-audio-suspend.conf".source =
    ../files/wireplumber/wireplumber.conf.d/51-disable-audio-suspend.conf;

  home.file.".config/xournalpp/settings.xml".source = ../files/xournalpp/settings.xml;

  # yt-dlp itself is deliberately NOT in nixos/configuration.nix's package
  # list -- this nixpkgs' yt-dlp builds "master" from source and pulls in a
  # Deno/rusty-v8 JS-engine dependency (~800MB download, ~7GB unpacked,
  # includes building an LLVM toolchain), wildly disproportionate for a
  # 1-line config file. The config is still here for whenever yt-dlp gets
  # installed (manually, or once nixpkgs ships a lighter build).
  home.file.".config/yt-dlp/config".source = ../files/yt-dlp/config;
}

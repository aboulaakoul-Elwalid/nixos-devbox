{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/hyprland.nix
    ./modules/waybar.nix
    ./modules/terminals.nix
    ./modules/shell.nix
    ./modules/git.nix
  ];

  # --- CHANGE THIS: these two values are specific to elwalid's account on the
  # source machine. Set them to your own username/home directory before
  # running `nixos-rebuild switch`. They MUST match the `users.users.<name>`
  # block you configure in nixos/configuration.nix.
  home.username = "elwalid";
  home.homeDirectory = "/home/elwalid";

  # Must match the `system.stateVersion` in nixos/configuration.nix (25.11
  # on the source machine). Do not bump this on new installs just to match
  # a newer Home Manager release -- see the Home Manager release notes.
  home.stateVersion = "25.11";

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;

  # Everything else (Hyprland, waybar, terminals, shell, git) is wired up in
  # ./modules/*.nix, which drop the copied dotfiles from ./files/ into place
  # via home.file / xdg.configFile.
}

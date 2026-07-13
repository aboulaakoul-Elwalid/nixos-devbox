# Shell: zsh + Powerlevel10k, Starship (unused by default -- p10k is the
# active prompt, see PROMPT_MODE in .zshrc), and tmux.
#
# .zshrc expects a number of CLI tools to already be on PATH: zoxide, direnv,
# fzf, jj (jujutsu), atuin (optional, only used if present), eza, bat, fd,
# ripgrep, starship. Most of these are already listed in
# nixos/configuration.nix's environment.systemPackages. `atuin` and
# `oh-my-zsh` are NOT in that list and are treated as optional by .zshrc
# (both are guarded by existence/command checks) -- install them yourself if
# you want that parity, or trim the guarded blocks out of .zshrc.
{ config, pkgs, lib, ... }:

{
  home.file = {
    ".zshrc".source = ../files/zsh/zshrc;
    ".p10k.zsh".source = ../files/zsh/p10k.zsh;
  };

  xdg.configFile = {
    "starship.toml".source = ../files/starship/starship.toml;
    "tmux/tmux.conf".source = ../files/tmux/tmux.conf;
  };
}

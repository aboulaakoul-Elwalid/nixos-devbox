# Editor and CLI-tool configs that round out the dev experience: Neovim
# (LazyVim-based -- init.lua/lua/plugin, plugin lockfile), lazygit, lazydocker,
# btop, walker (app launcher), mise (tool version manager), direnv's own
# config (see modules/dev-templates.nix for its project-scaffolding
# templates, which are separate from this), and espanso (text-expander --
# just a generic autocorrect ruleset + a downloaded "misspell-en" package,
# no personal snippets).
#
# npm-global convention: .zshrc and several aliases (opencode, codex-real,
# etc.) expect globally-installed npm packages under ~/.npm-global/bin. If
# you use npm-installed CLIs, set that up yourself:
#   npm config set prefix ~/.npm-global
# (Not shipped as a file here because the source machine's ~/.npmrc also has
# a live npm auth token in it, which is exactly the kind of thing this repo
# is careful to never include -- just the one prefix line, added yourself.)
{ config, pkgs, lib, ... }:

{
  xdg.configFile = {
    "nvim" = {
      source = ../files/nvim;
      recursive = true;
    };
    "lazygit/config.yml".source = ../files/lazygit/config.yml;
    "lazydocker/config.yml".source = ../files/lazydocker/config.yml;
    "btop" = {
      source = ../files/btop;
      recursive = true;
    };
    "walker/config.toml".source = ../files/walker/config.toml;
    "mise/config.toml".source = ../files/mise/config.toml;
    "direnv/direnvrc".source = ../files/direnv/direnvrc;
    # direnv/lib is genuinely empty on the source machine (no custom stdlib
    # extensions) -- nothing to ship, and git doesn't track empty dirs anyway.
    "espanso" = {
      source = ../files/espanso;
      recursive = true;
    };
  };
}

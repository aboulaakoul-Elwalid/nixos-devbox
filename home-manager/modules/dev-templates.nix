# Project scaffolding templates used by the `nix-init` and `project-init`
# shell functions in .zshrc (see modules/shell.nix / files/zsh/zshrc).
{ config, pkgs, lib, ... }:

{
  xdg.configFile = {
    "nix/templates/ai/flake.nix".source = ../files/nix-templates/ai/flake.nix;
    "nix/templates/go/flake.nix".source = ../files/nix-templates/go/flake.nix;
    "nix/templates/node/flake.nix".source = ../files/nix-templates/node/flake.nix;
    "nix/templates/python/flake.nix".source = ../files/nix-templates/python/flake.nix;
    "nix/templates/rust/flake.nix".source = ../files/nix-templates/rust/flake.nix;

    "direnv/templates/ai-project.envrc".source = ../files/direnv-templates/ai-project.envrc;
    "direnv/templates/nix.envrc".source = ../files/direnv-templates/nix.envrc;
    "direnv/templates/python.envrc".source = ../files/direnv-templates/python.envrc;
  };
}

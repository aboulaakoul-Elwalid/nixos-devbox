# Zellij (terminal multiplexer): base config, color theme, and layouts.
#
# Two of the shipped layouts reference tools/paths that are personal to the
# source machine and are NOT included in this export:
#   - layouts/agents.kdl references ~/.local/bin/co1, ~/.local/bin/co10
#     (personal Codex multi-instance wrapper scripts) and a `gemini` CLI.
#   - layouts/opencode.kdl references ~/.opencode/bin/opencode directly
#     (the .zshrc alias instead points opencode at ~/.local/bin/opencode --
#     these two disagree even on the source machine).
# Both also hardcode `cwd "/home/elwalid"`. Edit or delete these two layout
# files to match your own home directory and installed tools; the rest
# (config.kdl, themes/custom.kdl, layouts/default.kdl, ghost.kdl, stealth.kdl,
# logs.kdl) are generic aside from `logs.kdl`'s `cwd`, which also needs your
# home directory.
{ config, pkgs, lib, ... }:

{
  xdg.configFile = {
    "zellij/config.kdl".source = ../files/zellij/config.kdl;
    "zellij/themes/custom.kdl".source = ../files/zellij/themes/custom.kdl;
    "zellij/layouts/default.kdl".source = ../files/zellij/layouts/default.kdl;
    "zellij/layouts/ghost.kdl".source = ../files/zellij/layouts/ghost.kdl;
    "zellij/layouts/stealth.kdl".source = ../files/zellij/layouts/stealth.kdl;
    "zellij/layouts/logs.kdl".source = ../files/zellij/layouts/logs.kdl;
    "zellij/layouts/agents.kdl".source = ../files/zellij/layouts/agents.kdl;
    "zellij/layouts/opencode.kdl".source = ../files/zellij/layouts/opencode.kdl;
  };
}

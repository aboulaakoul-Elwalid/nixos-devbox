# Sets the npm global-install prefix to ~/.npm-global, matching the
# convention .zshrc's PATH already expects ($HOME/.npm-global/bin). This is
# ONLY the prefix line -- the source machine's ~/.npmrc also has a live npm
# auth token in it, deliberately never included anywhere in this repo.
# Installing the actual CLI packages (codex, opencode-ai, etc.) into that
# prefix is a separate step -- see AGENTS.md / the top-level README.
{ config, pkgs, lib, ... }:

{
  home.file.".npmrc".text = "prefix=${config.home.homeDirectory}/.npm-global\n";
}

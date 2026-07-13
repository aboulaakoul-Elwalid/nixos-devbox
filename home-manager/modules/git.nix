# Git configuration.
#
# CHANGE THIS: [user] name/email below are elwalid's. Edit
# home-manager/files/git/config (or override with `programs.git` options)
# before rebuilding.
#
# No credentials are included. `credential.helper = store` and the
# `gh auth git-credential` helpers just tell git *how* to look up/cache
# credentials -- the actual GitHub auth happens when you run `gh auth login`
# yourself. The `smartpush` alias points at `~/bin/git-smart-push`, which is
# NOT included in this repo (it shells out to a personal `opencode` AI
# review setup) -- remove the alias or write your own script if you want it.
{ config, pkgs, lib, ... }:

{
  xdg.configFile = {
    "git/config".source = ../files/git/config;
    "git/ignore".source = ../files/git/ignore;
  };
}

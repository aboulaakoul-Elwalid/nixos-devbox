# Waybar status bar configuration.
{ config, pkgs, lib, ... }:

{
  xdg.configFile = {
    "waybar/config.jsonc".source = ../files/waybar/config.jsonc;
    "waybar/style.css".source = ../files/waybar/style.css;

    "waybar/scripts/activitywatch-safe.sh" = {
      source = ../files/waybar/scripts/activitywatch-safe.sh;
      executable = true;
    };
    "waybar/scripts/activitywatch-status.sh" = {
      source = ../files/waybar/scripts/activitywatch-status.sh;
      executable = true;
    };
    # ai-credits-safe.sh degrades gracefully: it calls ~/.local/bin/ai-credits-waybar
    # and ~/.cache/.bun/bin/tokscale, neither of which is included in this repo
    # (personal AI-usage/account tooling, deliberately excluded -- see the
    # export report). The waybar module still works, it just shows a plain
    # token counter instead of the full AI-credits dashboard.
    "waybar/scripts/ai-credits-safe.sh" = {
      source = ../files/waybar/scripts/ai-credits-safe.sh;
      executable = true;
    };
    "waybar/scripts/gpu-safe.sh" = {
      source = ../files/waybar/scripts/gpu-safe.sh;
      executable = true;
    };
    "waybar/scripts/lib/cache.sh" = {
      source = ../files/waybar/scripts/lib/cache.sh;
      executable = true;
    };
  };
}

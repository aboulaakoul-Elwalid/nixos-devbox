# Systemd --user service/timer files that make the desktop actually work:
# waybar, the wallpaper daemon (swaybg), hyprshell (workspace/window
# switcher), elephant (walker's search backend), and Omarchy's
# battery-monitor/theme-rotate timers.
#
# IMPORTANT: none of this comes from the `omanix` flake module or any Nix
# package -- on the source machine these are plain hand-placed files under
# ~/.config/systemd/user/ and ~/.config/systemd/scripts/, predating/parallel
# to omanix, and home-manager's omanix module (omanix.homeManagerModules)
# is NOT wired into this flake at all (deliberately -- it ships its own,
# different theme system that would conflict with the omarchy/ directory
# approach in modules/theme.nix). Without this module, hypr/autostart.conf's
# `systemctl --user start omarchy-waybar.service omarchy-swaybg.service`
# line just silently fails (no waybar, no wallpaper) because those units
# don't exist yet.
{ config, pkgs, lib, ... }:

{
  xdg.configFile = {
    "systemd/user/omarchy-waybar.service".source = ../files/systemd-user/units/omarchy-waybar.service;
    "systemd/user/omarchy-swaybg.service".source = ../files/systemd-user/units/omarchy-swaybg.service;
    "systemd/user/hyprshell.service".source = ../files/systemd-user/units/hyprshell.service;
    "systemd/user/hyprshell-restart.service".source = ../files/systemd-user/units/hyprshell-restart.service;
    "systemd/user/hyprshell-watchdog.service".source = ../files/systemd-user/units/hyprshell-watchdog.service;
    "systemd/user/hyprshell-watchdog.timer".source = ../files/systemd-user/units/hyprshell-watchdog.timer;
    "systemd/user/hyprshell-healthcheck.service".source = ../files/systemd-user/units/hyprshell-healthcheck.service;
    "systemd/user/hyprshell-healthcheck.timer".source = ../files/systemd-user/units/hyprshell-healthcheck.timer;
    "systemd/user/omarchy-battery-monitor.service".source = ../files/systemd-user/units/omarchy-battery-monitor.service;
    "systemd/user/omarchy-battery-monitor.timer".source = ../files/systemd-user/units/omarchy-battery-monitor.timer;
    "systemd/user/omarchy-theme-rotate.service".source = ../files/systemd-user/units/omarchy-theme-rotate.service;
    "systemd/user/omarchy-theme-rotate.timer".source = ../files/systemd-user/units/omarchy-theme-rotate.timer;
    "systemd/user/elephant.service".source = ../files/systemd-user/units/elephant.service;

    # Daily-log screenshot capture (every 30s) + nightly rollup into a
    # timelapse video ($HOME/Videos/daily-logs/YYYY-MM-DD/day.mp4 via
    # ffmpeg). Pure automation software, no AI/local-model dependency --
    # that's a separate dailylog-summarize-day script, deliberately not
    # included since it needs elwalid's personal local-LLM setup.
    "systemd/user/dailylog-snap.service".source = ../files/systemd-user/units/dailylog-snap.service;
    "systemd/user/dailylog-snap.timer".source = ../files/systemd-user/units/dailylog-snap.timer;
    "systemd/user/dailylog-rollup.service".source = ../files/systemd-user/units/dailylog-rollup.service;
    "systemd/user/dailylog-rollup.timer".source = ../files/systemd-user/units/dailylog-rollup.timer;

    # "enabled" symlinks (what `systemctl --user enable` would create) --
    # omarchy-waybar/swaybg/hyprshell get explicitly `systemctl --user
    # start`ed by hypr/autostart.conf regardless, but elephant and all the
    # timers need this to actually fire on their own.
    "systemd/user/graphical-session.target.wants/elephant.service".source = ../files/systemd-user/units/elephant.service;
    "systemd/user/timers.target.wants/omarchy-battery-monitor.timer".source = ../files/systemd-user/units/omarchy-battery-monitor.timer;
    "systemd/user/timers.target.wants/omarchy-theme-rotate.timer".source = ../files/systemd-user/units/omarchy-theme-rotate.timer;
    "systemd/user/timers.target.wants/hyprshell-watchdog.timer".source = ../files/systemd-user/units/hyprshell-watchdog.timer;
    "systemd/user/graphical-session.target.wants/hyprshell-healthcheck.timer".source = ../files/systemd-user/units/hyprshell-healthcheck.timer;
    "systemd/user/timers.target.wants/dailylog-snap.timer".source = ../files/systemd-user/units/dailylog-snap.timer;
    "systemd/user/timers.target.wants/dailylog-rollup.timer".source = ../files/systemd-user/units/dailylog-rollup.timer;

    "systemd/scripts/wait-hypr-monitor.sh" = {
      source = ../files/systemd-user/scripts/wait-hypr-monitor.sh;
      executable = true;
    };
    "systemd/scripts/hyprshell-prestart.sh" = {
      source = ../files/systemd-user/scripts/hyprshell-prestart.sh;
      executable = true;
    };
    "systemd/scripts/hyprshell-poststart.sh" = {
      source = ../files/systemd-user/scripts/hyprshell-poststart.sh;
      executable = true;
    };
    "systemd/scripts/hyprshell-healthcheck.sh" = {
      source = ../files/systemd-user/scripts/hyprshell-healthcheck.sh;
      executable = true;
    };
  };
}

#!/usr/bin/env bash

# NixOS-native Omarchy menu overrides.
# This file is sourced by ~/.local/share/omarchy/bin/omarchy-menu.

show_main_menu() {
  go_to_menu "$(menu "NixOS" "󰀻  Apps\n󱓞  Actions\n  Style\n  Setup\n  Install\n󰭌  Remove\n  System Update\n󰧑  Docs\n  About\n  Power")"
}

show_learn_menu() {
  case $(menu "Docs" "  NixOS Manual\n󱄅  Nix Pills\n  Home Manager\n󰈙  Hyprland Wiki\n  Neovim") in
  *"NixOS Manual"*) omarchy-launch-webapp "https://nixos.org/manual/nixos/stable/" ;;
  *"Nix Pills"*) omarchy-launch-webapp "https://nixos.org/guides/nix-pills/" ;;
  *"Home Manager"*) omarchy-launch-webapp "https://nix-community.github.io/home-manager/" ;;
  *"Hyprland Wiki"*) omarchy-launch-webapp "https://wiki.hypr.land/" ;;
  *Neovim*) omarchy-launch-webapp "https://www.lazyvim.org/keymaps" ;;
  *) show_main_menu ;;
  esac
}

go_to_menu() {
  case "${1,,}" in
  *apps*) walker -p "Launch…" ;;
  *actions*) show_trigger_menu ;;
  *style*) show_style_menu ;;
  *setup*) show_setup_menu ;;
  *install*) show_install_menu ;;
  *remove*) show_remove_menu ;;
  *update*) show_update_menu ;;
  *docs*) show_learn_menu ;;
  *about*) show_about ;;
  *power*|*system*) show_system_menu ;;
  esac
}

show_install_menu() {
  case $(menu "Install" "  Package (Nix)\n󱚤  AI Tools\n  Editors\n  Terminal\n󰥔  Dictation (Local)") in
  *"Package (Nix)"*) present_terminal "omarchy-pkg-install" ;;
  *"AI Tools"*) show_install_ai_menu ;;
  *"Editors"*) show_install_editor_menu ;;
  *"Terminal"*) show_install_terminal_menu ;;
  *"Dictation (Local)"*) present_terminal "nix profile install nixpkgs#whisper-cpp nixpkgs#ffmpeg" ;;
  *) show_main_menu ;;
  esac
}

show_install_ai_menu() {
  case $(menu "AI Tools (NixOS)" "󱚤  Codex CLI\n󱚤  OpenCode\n󱚤  Gemini CLI\n󱚤  Antigravity CLI\n󰥔  Dictation Setup\n󱎓  Verify Auths") in
  *"Codex CLI"*) present_terminal "command -v codex && codex --version || npm install -g @openai/codex && codex --version" ;;
  *"OpenCode"*) present_terminal "command -v opencode && opencode --version || nix profile add nixpkgs#opencode && opencode --version" ;;
  *"Gemini CLI"*) present_terminal "command -v gemini && gemini --version || npm install -g @google/gemini-cli && gemini --version" ;;
  *"Antigravity CLI"*) present_terminal "command -v antigravity && antigravity --help | head -20 || echo 'antigravity shim installed in ~/.local/bin'" ;;
  *"Dictation Setup"*) present_terminal "dictate-local-setup && echo && echo 'Try: voxtype record toggle'" ;;
  *"Verify Auths"*) present_terminal "cd ~/projects 2>/dev/null || mkdir -p ~/projects && cd ~/projects && oc auth list && echo && oc models openai | head -10 && echo && oc models google | head -10 && echo && oc models github-copilot | head -10" ;;
  *) show_install_menu ;;
  esac
}

show_update_menu() {
  case $(menu "Update (NixOS)" "󱧼  Rebuild Test\n  Rebuild Switch\n  Flake Update + Switch\n  Garbage Collect\n󰂺  Analyze Boot\n  Commit /etc/nixos") in
  *"Rebuild Test"*) present_terminal "omarchy-nix-rebuild-test" ;;
  *"Rebuild Switch"*) present_terminal "omarchy-nix-rebuild-switch" ;;
  *"Flake Update"*) present_terminal "omarchy-nix-flake-update-switch" ;;
  *"Garbage Collect"*) present_terminal "omarchy-nix-gc" ;;
  *"Analyze Boot"*) present_terminal "systemd-analyze && echo && systemd-analyze blame | head -30" ;;
  *"Commit /etc/nixos"*) present_terminal "omarchy-nix-git-commit" ;;
  *) show_main_menu ;;
  esac
}

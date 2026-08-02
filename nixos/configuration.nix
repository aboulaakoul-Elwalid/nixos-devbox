# *** THIS-MACHINE'S CONFIG -- READ BEFORE REUSING ***
# This is the exact system configuration.nix from the source machine
# ("nixos"/elwalid). Most of it (packages, Hyprland, desktop services) is
# generic and portable, but several blocks below are specific to THIS
# machine's hardware/accounts and must be reviewed before you rebuild with
# it on your own disk. See the repo README for the full checklist; in
# short, look for and adjust:
#   - `networking.hostName` and the `users.users.elwalid` block
#   - `boot.initrd.luks.devices."luks-<uuid>"` (LUKS UUID, this machine's disk)
#   - `fileSystems."/mnt/hdd"` (an extra NTFS data drive on this machine only)
#   - `services.udev.extraRules` (UUID allow-list for this machine's drives)
#   - `services.keyd` (elwalid's personal QWERTY remap; remove if unwanted)
#
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:
let
  pythonLearning = pkgs.python313.withPackages (ps: with ps; [
    ipython
    matplotlib
    numpy
    pandas
    pandas-stubs
  ]);
  pythonLearningBin = pkgs.writeShellScriptBin "python-learning" ''
    exec ${pythonLearning}/bin/python3 "$@"
  '';
  latexToolchain = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-medium
      latexmk
      biber
      latexindent
      chktex
      minted
      collection-langfrench
      collection-langarabic
      collection-fontsrecommended;
  };
  antigravity = pkgs.stdenv.mkDerivation rec {
    pname = "antigravity";
    version = "2.0.1-6566078776737792";

    src = pkgs.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.0.1-6566078776737792/linux-x64/Antigravity.tar.gz";
      hash = "sha256-Byfh9WlhttI0eUHyeNppzGwX3jvv6YhSSEjNFnOA6as=";
    };

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook3
    ];

    buildInputs = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      krb5
      libdrm
      libgbm
      libglvnd
      libsecret
      libuuid
      libxkbfile
      libxkbcommon
      libsoup_3
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxscrnsaver
      libxtst
      mesa
      nspr
      nss
      pango
      udev
      vulkan-loader
      webkitgtk_4_1
      zlib
    ];

    unpackPhase = ''
      runHook preUnpack
      tar -xzf "$src" --strip-components=1
      chmod 0755 chrome-sandbox
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/antigravity" "$out/bin" "$out/share/applications"
      cp -r . "$out/share/antigravity/"

      makeWrapper "$out/share/antigravity/antigravity" "$out/bin/antigravity" \
        --set NIXOS_OZONE_WL 1 \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.libglvnd pkgs.mesa pkgs.vulkan-loader pkgs.libdrm ]}" \
        --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}" \
        --add-flags "--ozone-platform-hint=auto"

      cat > "$out/share/applications/antigravity.desktop" <<EOF
      [Desktop Entry]
      Name=Google Antigravity
      Comment=Google Antigravity
      Exec=antigravity %U
      Terminal=false
      Type=Application
      Categories=Development;IDE;
      StartupWMClass=Antigravity
      EOF

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Google Antigravity";
      homepage = "https://antigravity.google/";
      license = licenses.unfree;
      mainProgram = "antigravity";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.loader.timeout = 5;
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.tpm2.enable = true;
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "quiet"
    "loglevel=3"
    "rd.systemd.show_status=auto"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
  boot.kernelModules = [ "nvidia_drm" ];

  boot.extraModprobeConfig = "options snd_hda_intel power_save=0 power_save_controller=N";

  boot.initrd.luks.devices."luks-1f8ba60f-0725-4a15-8c91-f894c75ec492".crypttabExtraOpts = [ "tpm2-device=auto" ];

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  networking.networkmanager.plugins = with pkgs; [
    networkmanager-openvpn

  ];

  time.timeZone = "Africa/Casablanca";
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.users.elwalid = {
    isNormalUser = true;
    description = "elwalid";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [];
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (final: prev: {
      netexec = prev.netexec.overridePythonAttrs (old: {
        dependencies = builtins.map (
          dep:
          if (dep.pname or "") == "certipy-ad" then
            dep.overridePythonAttrs (certipyOld: {
              pythonRelaxDeps = (certipyOld.pythonRelaxDeps or [ ]) ++ [ "requests" ];
            })
          else
            dep
        ) old.dependencies;
      });
    })
  ];
  hardware.enableRedistributableFirmware = true;
  services.udev.packages = with pkgs; [ usb-modeswitch usb-modeswitch-data ];

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    ghostty
    kitty
    brave
    chromium
    xdg-utils
    nodejs_22

    bat
    eza
    fd
    fzf
    jq
    sqlite
    neovim
    ripgrep
    starship
    tmux
    yazi
    zellij
    zoxide

    rsync
    usbutils
    powertop
    whois
    tree
    unzip
    zip
    _7zz
    unar

    hypridle
    hyprlock
    hyprpicker
    hyprshot
    hyprsunset
    hyprshell
    mako
    slurp
    swayosd
    waybar
    wl-clipboard
    wtype
    voxtype-vulkan
    dotool
    pulseaudio
    vulkan-loader
    vulkan-tools
    wl-clip-persist
    xclip
    xdotool
    wireplumber
    pamixer
    playerctl
    wiremix
    pavucontrol
    activitywatch
    awatcher
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk

    docker
    docker-compose
    podman
    k3d
    kubectl
    kubernetes-helm

    go
    rustc
    cargo
    clang
    cmake
    (llama-cpp.override { vulkanSupport = true; })
    python3
    python3Packages.pip
    python3Packages.debugpy
    python3Packages.poetry-core
    python3Packages.requests
    jdk11

    gh
    gitleaks
    osv-scanner
    bitwarden-desktop
    _1password-cli
    _1password-gui
    antigravity
    google-chrome
    flatpak
    fcitx5
    fcitx5-gtk
    qt6Packages.fcitx5-qt
    gnome-keyring
    gnome-calculator
    seahorse
    lazygit
    lazydocker
    localsend
    fastfetch
    btop
    htop
    duf
    dust
    glances

    obs-studio
    mpv-unwrapped
    imagemagick
    poppler-utils
    ghostscript
    wl-screenrec
    libreoffice
    signal-desktop
    spotify
    obsidian
    tailscale
    nautilus
    nautilus-python
    stow
    tree-sitter
    typst
    tinymist
    latexToolchain
    texlab
    pandoc
    ruff
    ty
    pythonLearning
    pythonLearningBin
    python3Packages.virtualenv
    python3Packages.ipython
    python3Packages.jupyterlab
    python3Packages.pygments
    zsh-autosuggestions
    zsh-syntax-highlighting
    xournalpp
    xh
    xmlstarlet
    # Arch parity bundle (phase 3)
    alacritty
    zed-editor
    bun
    direnv
    brightnessctl
    bluetui
    gum
    inxi
    jj
    mise
    espanso  # not in the source machine's declared packages either (installed
             # out-of-band) -- added here so home-manager/modules/tools.nix's
             # espanso config actually has a binary to go with it. No autostart
             # is wired up anywhere; run `espanso start` yourself if you want it.
    pnpm
    ruby
    ffmpeg
    ffmpegthumbnailer
    evince
    zathura
    imv
    pinta
    satty
    swappy
    grim
    swaybg
    walker
    loupe
    file-roller
    elephant
    uv
    google-cloud-sdk
    networkmanagerapplet
    libnotify
    xcursor-themes
    vanilla-dmz
    yaru-theme
    font-awesome
    glib
    wofi
    ifuse
    ntfs3g
    exfatprogs
    socat
    ncdu
    openvpn
    networkmanager-openvpn  # NM plugin for GUI import
    sshpass
    mosh
    nmap
    netexec
    python3Packages.impacket
    samba
    openldap
    krb5
    hashcat
    john
    

    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    roboto-mono
    nerd-fonts.caskaydia-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  programs.zsh.enable = true;
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
    ];
  };
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
  };
  programs.uwsm.enable =  true;
  systemd.user.services.voxtype = {
    description = "Voxtype dictation daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = with pkgs; [
      dotool
      libnotify
      wl-clipboard
      wtype
    ];
    serviceConfig = {
      ExecStart = "${pkgs.voxtype-vulkan}/bin/voxtype daemon";
      Environment = "VOXTYPE_VULKAN_DEVICE=nvidia";
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
  fonts.packages = with pkgs; [
    roboto
    roboto-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.caskaydia-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];
  fonts.fontconfig = {
    defaultFonts = {
      monospace = [ "Roboto Mono" "JetBrainsMono Nerd Font" "CaskaydiaMono Nerd Font" "Noto Color Emoji" ];
      sansSerif = [ "Noto Sans" "Noto Color Emoji" ];
      serif = [ "Noto Serif" "Noto Color Emoji" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [ fcitx5-gtk qt6Packages.fcitx5-qt ];
    };
  };
  virtualisation.docker.enable = true;
  virtualisation.podman.enable = lib.mkForce false;

  services.flatpak.enable = true;
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PubkeyAuthentication = true;
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      ClientAliveInterval = 30;
      ClientAliveCountMax = 3;
      X11Forwarding = false;
    };
  };
  services.tailscale.enable = true;
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };
  services.power-profiles-daemon.enable = true;
  powerManagement.powertop.enable = true;

  # Overnight power-saver window for unattended agent runs.
  systemd.services."power-profile-night" = {
    description = "Switch to power-saver profile overnight";
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver";
  };
  systemd.timers."power-profile-night" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:00:00";
      Persistent = true;
    };
  };

  systemd.services."power-profile-day" = {
    description = "Switch back to balanced profile in the morning";
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced";
  };
  systemd.timers."power-profile-day" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 08:00:00";
      Persistent = true;
    };
  };

  services.gvfs.enable = true;
  services.udisks2.enable = true;
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 2222 ];
  networking.firewall.interfaces."tailscale0".allowedUDPPortRanges = [
    {
      from = 60000;
      to = 61000;
    }
  ];
  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="4A5E-6843", ENV{UDISKS_IGNORE}="1"
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="f749c155-3d4e-4bfb-b6f6-cc0447b1f2f8", ENV{UDISKS_IGNORE}="1"
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="5CFD-FF38", ENV{UDISKS_IGNORE}="1"
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="4440FF0140FEF90E", ENV{UDISKS_IGNORE}="1"
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="84F8CC84F8CC7648", ENV{UDISKS_IGNORE}="1"
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="81A5-E0C8", ENV{UDISKS_IGNORE}="1"
    SUBSYSTEM=="block", ENV{ID_FS_UUID}=="8c94b54a-502f-49e5-9328-dbde537275b8", ENV{UDISKS_IGNORE}="1"
  '';
  security.rtkit.enable = true;
  security.tpm2.enable = true;
  services.displayManager.sddm.enable = true;
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;
  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  omanix.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  services.keyd = {
    enable = true;
    keyboards.default.settings.main = {
      q = "a";
      a = "q";
      w = "z";
      z = "w";
      semicolon = "m";
      m = "semicolon";
    };
  };
  systemd.services.NetworkManager-wait-online.enable = false;
  boot.resumeDevice = lib.mkForce "";
  xdg.mime.defaultApplications = {
    "image/png" = "org.gnome.Loupe.desktop";
    "image/jpeg" = "org.gnome.Loupe.desktop";
    "image/gif" = "org.gnome.Loupe.desktop";
    "image/webp" = "org.gnome.Loupe.desktop";
    "image/bmp" = "org.gnome.Loupe.desktop";
    "image/tiff" = "org.gnome.Loupe.desktop";
    "image/svg+xml" = "org.gnome.Loupe.desktop";
    "application/zip" = "org.gnome.FileRoller.desktop";
    "application/x-zip-compressed" = "org.gnome.FileRoller.desktop";
    "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
    "application/x-rar" = "org.gnome.FileRoller.desktop";
    "application/vnd.rar" = "org.gnome.FileRoller.desktop";
    "application/x-rar-compressed" = "org.gnome.FileRoller.desktop";
    "application/x-tar" = "org.gnome.FileRoller.desktop";
    "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
    "application/x-bzip-compressed-tar" = "org.gnome.FileRoller.desktop";
    "application/x-xz-compressed-tar" = "org.gnome.FileRoller.desktop";
    "application/gzip" = "org.gnome.FileRoller.desktop";
  };
  swapDevices = lib.mkForce [ ];
  zramSwap = {
    enable = true;
    memoryPercent = 10;
    algorithm = "zstd";
    priority = 100;
  };
  # Fallback at boot: if this USB dongle appears in CDROM mode, switch it to NIC mode.
  systemd.services.tpLinkWifiModeswitch = {
    description = "Fallback USB mode switch for Realtek 0bda:1a2b";
    after = [ "systemd-udevd.service" ];
    wants = [ "systemd-udevd.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ usb-modeswitch usb-modeswitch-data usbutils coreutils gnugrep ];
    serviceConfig.Type = "oneshot";
    script = ''
      if lsusb | grep -qi '0bda:1a2b'; then
        echo "Switching Wi-Fi dongle out of CDROM mode (0bda:1a2b)"
        usb_modeswitch -W -v 0bda -p 1a2b \
          -c ${pkgs.usb-modeswitch-data}/share/usb_modeswitch/0bda:1a2b || true
        sleep 2
      fi
    '';
  };
  system.autoUpgrade = {
    enable = false;
    flake = "/etc/nixos";
    # update only nixpkgs input
    flags = [ "--update-input" "nixpkgs" "-L" ];
    dates = "daily";
    randomizedDelaySec = "45min";
    persistent = true;
    operation = "switch";
    allowReboot = false;
  };

  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-uuid/0858F4D658F4C40A";
    fsType = "ntfs-3g";
    options = [
      "nofail"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=10s"
      "uid=1000"
      "gid=100"
      "umask=0022"
      "windows_names"
    ];
  };
  system.stateVersion = "25.11";
}

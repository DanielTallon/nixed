# /.dotfiles/modules/packages.nix
{
  # NOTE:`pkgs-unstable` is the nixos-unstable channel on both hosts. On the
  # unstable branch, it's the same nixpkgs as the base `pkgs`, so it changes nothing
  # there. On nixos-stable (base `pkgs` = 26.05) it's the real opt-in:
  # `pkgs-unstable.somePackage` for the occasional package you want off unstable.

  flake.modules.nixos.packages = { config, pkgs, pkgs-stable, pkgs-unstable, inputs, username, ... }:
  let
    system = pkgs.stdenv.hostPlatform.system;
    nix-packages = inputs.nix-packages.packages.${system};
    #zen-browser = inputs.zen-browser.packages.${system}.default;
  in
  {
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.problems.handlers = {
      cups.broken = "warn"; # or "ignore" to silence entirely
    };

    hardware.graphics.enable32Bit = true;

    environment.systemPackages = with pkgs; [
      # --- Browsers ---
      brave
      #librewolf is installed, but has it's own .nix file


      # --- General ---
      #pkgs-unstable is default for desktop
      baobab
      comma
      drawy
      easyeffects
      ffmpeg
      fish
      flatpak
      fzf
      gh
      git
      gimp
      gpu-screen-recorder-gtk
      headsetcontrol
      imagemagick
      kdePackages.kdialog
      kdePackages.kolourpaint
      lact
      lazygit
      localsend
      nixd
      onlyoffice-desktopeditors
      pkgs-stable.inetutils #Watch Star Wars with telnet towel.blinkenlights.nl
      pass
      pdfarranger
      py7zr
      spotdl
      superfile
      tealdeer
      tree
      usbimager #Used for flashing new ISOs on a USB
      usbutils
      wget
      xsettingsd
      xrdb
      xxd
      zenity

      # --- KDE ---
      kdePackages.konsole
      kdePackages.kate
      (kdePackages.discover.overrideAttrs (_old: {
        postFixup = ''
          wrapProgram $out/bin/plasma-discover \
            --add-flags "--backends flatpak"
        '';
      }))

      # --- Music, Audio, Video ---
      audacity
      deno # Required for spotdl: nix-shell -p spotdl URL
      #pkgs-stable.davinci-resolve #Vdeo Editing
      #pkgs-stable.openshot-qt #Video Editing
      parabolic
      pkgs-stable.obs-studio
      pkgs-stable.vlc
      tauon #Music Player
      pkgs-unstable.unimatrix

      # --- Utilities ---
      dysk
      kdePackages.kcalc    # Traditional scientific calculator
      keepassxc
      nix-update
      pv
      upscaler
      unzip

      # --- My packages (DanielTallon/nix-packages) ---
      nix-packages.boot-gardener
      nix-packages.kenku-fm
      nix-packages.lgl-papercutter

      # --- Nix Tooling ---
      deadnix   # Find unused bindings/arguments in .nix files
      nix-init  # Generate package derivations from a URL
      nurl      # Generate fetcher calls (with hashes) from a URL
      statix    # Lint .nix files for antipatterns (`statix fix` auto-fixes)

      # --- System & Monitoring ---
      (pkgs.btop.override { cudaSupport = config.hasNvidia; }) #BTop (GPU stats on NVIDIA hosts)
      mission-center
      nix-output-monitor
      nvd

      # --- iPhone ---
      ifuse
      # NOTE: First Time Run: mkdir -p ~/mnt/vlc
      # ifuse --documents org.videolan.vlc-ios ~/mnt/vlc
      # cp -r ~/Music/SomeAlbum ~/mnt/vlc/
      # fusermount -u ~/mnt/vlc
      libimobiledevice
      # NOTE: First Time Run: mkdir -p ~/iphone-backup
      # NOTE: Then Run: idevicebackup2 backup --full ~/iphone-backup
      # NOTE: To check on backup progress run: watch -n 5 du -sh ~/iphone-backup
      # Or: watch -n 5 du -sm ~/iphone-backup
      # NOTE: Restore later with: idevicebackup2 restore ~/iphone-backup
      # NOTE: idevicebackup2 -i encryption on ~/iphone-backup
      # NOTE: Unencrypted is still a good backup. It just leaves out saved passwords, Health data, and Wi-Fi settings, which iOS only includes when backups are encrypted. If you don't care about those, just skip.

      idevicerestore

      # --- Notes & Recording ---
      obsidian

      # --- Stable-pinned packages ---
      pkgs-stable.bottles

      # --- Gaming ---
      heroic-unwrapped
      mangohud # Track FPS of games
      mangojuice # GUI configure MangoHud
      jq
      protontricks
      protonplus
      steamtinkerlaunch
      wine
      xdotool
      xwininfo
      yad
      dxvk
      vkd3d-proton
      pkgs-stable.tetris

    ];

    services.flatpak.enable = true;
    services.packagekit.enable = false;

    # --- Nix-ld: Run unpatched binaries that require FSH ---
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        freetype
        libX11
        libXcursor
        libXrandr
        libXinerama
        libXi
        libXxf86vm
        libGL
        pkgsi686Linux.freetype
        stdenv.cc.cc.lib
        vulkan-loader
        vulkan-validation-layers
      ];
    };

    # --- Brave Settings ---
    programs.chromium = {
      enable = true;
        extraOpts = {
          BraveWalletDisabled       = true;
          BraveNewsDisabled         = true;
          BraveTalkDisabled         = true;
          BraveAIChatEnabled        = false;
          BraveRewardsDisabled      = true;
          BraveVPNDisabled          = true;
          MetricsReportingEnabled   = false;
          BraveStatsPingEnabled     = false;
          BraveWebDiscoveryEnabled  = false;
        };
      };

    # --- Shell ---
    programs.fish.enable = true;
        users.users.${username} = {
      shell = pkgs.fish;
      extraGroups = [ "gamemode" ];
    };

    # --- AppImage support ---
    programs.appimage = {
      enable = true;
      binfmt = true;
    };


    # --- Gameing: Steam ---
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
#         proton-ge-bin nix-packages.proton-ge-w3rt
        nix-packages.proton-wineland
        #inputs.nix-proton-cachyos.packages.${pkgs.stdenv.hostPlatform.system}.proton-cachyos
        #run: nix flake update nix-proton-cachyos, first before uncommenting out the line above.
      ];
    };

    # --- Gaming: Gamescope ---
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };

    # --- Gaming: Gamemode ---
        programs.gamemode = {
          enable = true;
          settings = {
            general.renice = 10;
            cpu.park_cores = "no";
          };
        };

    programs.command-not-found.enable = false;

    # --- XBox Gaming Controller Support ---
    hardware.xone.enable = true;
    hardware.xpadneo.enable = true;

    # --- nh: NixOS helper with auto-clean ---
    programs.nh = {
      enable = true;
      flake = "/home/${username}/.dotfiles/";
      clean = {
        enable = true;
        extraArgs = "--keep 35";
        dates = "*-*-* 12:00:00"; # "*-*-*" means every day, "12:00:00" is noon
        #dates = "weekly"; is another option

      };
    };
      environment.plasma6.excludePackages = with pkgs.kdePackages; [
        elisa
        konversation
      ];

      programs.kde-pim.enable = false;   # removes KMail, Kontact, Merkuro, Akonadi, kdepim-runtime
  };
}

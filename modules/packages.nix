# /.dotfiles/modules/packages.nix
{
  # NOTE:`pkgs-unstable` defaults to `pkgs` itself when not passed via specialArgs
  # (true on the desktop, where the base `pkgs` already IS unstable). On the
  # laptop (base `pkgs` = 26.05 stable), `pkgs-unstable` is the real opt-in
  # unstable channel — use it like `pkgs-unstable.somePackage` for the
  # occasional package you want off unstable there.
  flake.modules.nixos.packages = { pkgs, pkgs-stable, pkgs-unstable ? pkgs, inputs, username, ... }: {
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.problems.handlers = {
      cups.broken = "warn"; # or "ignore" to silence entirely
    };

    hardware.graphics.enable32Bit = true;

    environment.systemPackages = with pkgs; [
      # --- General ---
      #pkgs-unstable.
      brave
      baobab
      comma
      drawy
      easyeffects
      ffmpeg
      fish
      flatpak
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
      librewolf
      localsend
      mcp-nixos
      nixd
      onlyoffice-desktopeditors
      pkgs-stable.inetutils #Watch Star Wars with telnet towel.blinkenlights.nl
      pass
      py7zr
      spotdl
      superfile
      tree
      usbutils
      wget
      xsettingsd
      xrdb
      xxd
      zenity

      nix-update

      #discord
      #libreoffice
      #vesktop
      #vim


      # --- KDE ---
      kdePackages.konsole
      kdePackages.kate
      (kdePackages.discover.overrideAttrs (old: {
        postFixup = ''
          wrapProgram $out/bin/plasma-discover \
            --add-flags "--backends flatpak"
        '';
      }))

      # --- Music, Audio, Video ---
      audacity
      davinci-resolve
      parabolic
      pkgs-stable.obs-studio
      #pkgs-stable.strawberry
      pkgs-stable.vlc
      tauon
      deno # Required for spotdl: nix-shell -p spotdl URL

      # --- Utilities ---
      dysk
      keepassxc
      upscaler
      unzip

      # --- System & Monitoring ---
      # --- BTop ---
        (pkgs.btop.override { cudaSupport = true; })
      ifuse
      libimobiledevice
      mission-center
      nix-output-monitor
      nvd
      unimatrix

      # --- Notes & Recording ---
      obsidian

      # --- Stable-pinned packages ---
      pkgs-stable.bottles

      # --- Gaming ---
      heroic-unwrapped
      mangohud
      mangojuice
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
        #pkgs-stable.
        vulkan-loader
        #pkgs-stable.
        vulkan-validation-layers
      ];
    };

    # --- Shell ---
    programs.fish.enable = true;
    users.users.${username}.shell = pkgs.fish;

    # --- AppImage support ---
    programs.appimage = {
      enable = true;
      binfmt = true;
    };


    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
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
    programs.gamemode.enable = true;
    programs.command-not-found.enable = false;

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

  };
}

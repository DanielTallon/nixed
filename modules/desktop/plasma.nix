# /.dotfiles/modules/desktop/plasma.nix (Desktop Environment)
# KDE Plasma 6: the NixOS side (SDDM, Plasma, portals, which KDE apps ship)
# and the plasma-manager side (effects, window rules, shortcuts, power).
{ inputs, ... }:
{
  flake.modules.nixos.plasma = { pkgs, lib, username, ... }:
  let
    nix-packages = inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system};
  in
  {
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;

    # --- Display Server ---
    services.xserver = {
      enable = true;
      xkb = {
        layout = lib.mkDefault "us";
        variant = lib.mkDefault "";
      };
    };

    # --- Autologin ---
    services.displayManager.autoLogin = {
      enable = true;
      user = username;
    };

    # --- KWallet / PAM ---
    security.pam.services.sddm.kwallet.enable = true;
    security.pam.services.${username}.kwallet.enable = true;
    security.pam.services.sddm.kwallet.package = pkgs.kdePackages.kwallet-pam;

    # --- Wayland Support ---
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];

      config = {
        common = {
          default = [ "kde" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        };
        kde = {
          default = [ "kde" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        };
      };
    };

    # --- KDE apps ---
    # Discover's own update page can't install system updates anyway; the
    # Flatpak-only Discover comes from modules/desktop/flatpak.nix.
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      discover
      elisa
      konversation
    ];
    programs.kde-pim.enable = false;   # removes KMail, Kontact, Merkuro, Akonadi, kdepim-runtime

    environment.systemPackages = with pkgs; [
      kdePackages.kcalc    # Traditional scientific calculator
      kdePackages.kdialog
      kdePackages.kolourpaint
      nix-packages.wallpaperpicker  # started on login by the autostart entry below
    ];

    # --- Image viewer ---
    # Open pictures (LocalSend, Dolphin, xdg-open) in Gwenview instead of
    # whatever claims them first (GIMP). GIMP keeps its own .xcf files.
    xdg.mime.defaultApplications = lib.genAttrs [
      "image/avif" "image/bmp" "image/gif" "image/heif" "image/jpeg"
      "image/jxl" "image/png" "image/svg+xml" "image/tiff" "image/webp"
      "image/x-ico" "image/x-tga"
    ] (_: "org.kde.gwenview.desktop");

    # --- Alternative Desktop Environments (commented out) ---
    # GNOME
    # services.displayManager.gdm.enable = true;
    # services.desktopManager.gnome.enable = true;
    # environment.systemPackages = with pkgs; [ gnome-tweaks ];

    # XFCE
    # services.xserver.desktopManager.xfce.enable = true;
    # services.displayManager.defaultSession = "xfce";
    # environment.systemPackages = with pkgs; [ xfce.thunar ];

    # COSMIC
    # services.desktopManager.cosmic.enable = true;
    # services.displayManager.cosmic-greeter.enable = true;
  };

  flake.modules.homeManager.plasma = { config, pkgs, lib, ... }:
  let
    # Folders Baloo (file search indexer) should skip.
    # Trailing slash required; $HOME is expanded via shellExpand below.
    balooExcludes = [
      "$HOME/iphone-backup/"
      "$HOME/Games/"
      "$HOME/Develop/"
    ];
  in
  {
    # --- Plasma ---
    programs.plasma = {
      enable = true;

    # Kickoff icon: "nix-snowflake" (blue) or "nix-snowflake-white"
      startup.desktopScript."kickoff-nix-icon" = {
        text = ''
          panels().forEach(p =>
            p.widgets("org.kde.plasma.kickoff").forEach(w => {
              w.currentConfigGroup = ["General"];
              w.writeConfig("icon", "nix-snowflake"); // or "nix-snowflake-white"
            })
          );
        '';
      };


    # Disable hot corners/edges ONCE on first login.
    # Re-runs only if this text changes, so GUI changes are kept.
      startup.startupScript."disable-screen-edges" = {
        text = ''
          kw=${pkgs.kdePackages.kconfig}/bin/kwriteconfig6

          for edge in Top TopRight Right BottomRight Bottom BottomLeft Left TopLeft; do
            $kw --file kwinrc --group ElectricBorders --key "$edge" None
          done

          $kw --file kwinrc --group Effect-overview --key BorderActivate 9
          $kw --file kwinrc --group TabBox          --key BorderActivate 9

          ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.KWin /KWin reconfigure || true
        '';
      };


      kwin = {
        effects = {
          hideCursor = {
              enable = true;
          };
          blur = {
            enable = true;
            strength = 6; # Adjust strength (0-10)
            noiseStrength = 0;
          };
          translucency.enable = true;
        };
      };
      window-rules = [
        {
          description = "Konsole borderless";
          match = {
            window-class = { value = "konsole"; type = "substring"; };
            window-types = [ "normal" ];
          };
          apply = {
            noborder = { value = true; apply = "force"; };
          };
        }
      ];
      # Wallpaper picker (nix-packages.wallpaperpicker; started by the autostart entry below)
      hotkeys.commands."wallpaperpicker" = {
        name = "Wallpaper picker";
        key = "Meta+Space";
        command = "wallpaperpicker toggle";
      };
      workspace = {
        lookAndFeel = "org.kde.breezedark.desktop";
        colorScheme = "BreezeDark";
        theme = "breeze-dark";
      };
      configFile = {
    # Enable background blur in Konsole profile
        "konsole.conf"."General"."BackgroundMode" = 1; # 1 for transparency/blur
        "konsole.conf"."General"."BackgroundTransparency" = 50; # 0-100


    # Geometry Change: animates windows that are moved/resized by programs or scripts (e.g. Krohnkite re-tiling). You can enabled this via System Settings > Window Management > Desktop Effects.
        "kwinrc".Plugins.kwin4_effect_geometry_changeEnabled = true;
        "kwinrc".Effect-kwin4_effect_geometry_change.Duration = 500;
        "kscreenrc".Config.autoRotate = false;
        "ksmserverrc".General.confirmLogout = false;
        # Accent color from wallpaper: see wallpaper-colors.nix

        "breezerc"."Common" = {
          ShadowSize = "ShadowMedium";
          ShadowStrength = 255;
          ShadowColor = "0,170,255";
        };

        # Baloo file indexing: exclusions (this list owns the setting;
        # GUI changes in System Settings > Search will be overwritten)
        "baloofilerc".General."exclude folders" = {
          value = lib.concatStringsSep "," balooExcludes;
          shellExpand = true;
        };
        # Trash: auto-delete items older than 35 days.
        # The group name is the trash path; plasma-manager treats "/" as a
        # nested-group separator, so each slash is escaped as "\/".
        "ktrashrc".${lib.replaceStrings [ "/" ] [ "\\/" ] "${config.home.homeDirectory}/.local/share/Trash"} = {
          UseTimeLimit = true;
          Days = 35;
        };
      };

      # --- Power management ---
      powerdevil.AC = {
        powerButtonAction = "shutDown";
        autoSuspend.action = "nothing";
        dimDisplay = {
          enable = true;
          idleTimeout = 600; # 10 minutes
        };
        turnOffDisplay.idleTimeout = "never";
        powerProfile = "balanced";
      };
      powerdevil.battery = {
        powerButtonAction = "shutDown";
        autoSuspend.action = "nothing";
        dimDisplay = {
          enable = true;
          idleTimeout = 600; # 10 minutes
        };
        turnOffDisplay.idleTimeout = "never";
        powerProfile = "balanced";
      };

      # --- Screen locking ---
      kscreenlocker = {
        autoLock = false;
        lockOnResume = false;
      };
    };

    # --- Wallpaper picker: start it on login (the hotkey above toggles it) ---
    xdg.configFile."autostart/wallpaperpicker.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=wallpaperpicker
      Exec=wallpaperpicker
      Icon=preferences-desktop-wallpaper
    '';
  };
}

# /.dotfiles/home-manager/plasma.nix
{
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
        {
          description = "Cavalier - float at bottom of second screen, full width, always below";
          match = {
            window-class = {
              value = "NickvisionCavalier.GNOME";
              type = "substring";
            };
          };
          apply = {
            position = {
              value = "0,794";
              apply = "force";
            };
            size = {
              value = "1920,286";
              apply = "force";
            };
            below = {
              value = true;
              apply = "force";
            };
          };
        }
      ];
      workspace = {
        lookAndFeel = "org.kde.breezedark.desktop";
        colorScheme = "BreezeDark";
        theme = "breeze-dark";
      };
      configFile = {
        # Enable background blur in Konsole profile
        "konsole.conf"."General"."BackgroundMode" = 1; # 1 for transparency/blur
        "konsole.conf"."General"."BackgroundTransparency" = 50; # 0-100

        # Disable hot corners/edges to avoid accidental triggers
        "kwinrc".ElectricBorders = {
          Top = "None";
          TopRight = "None";
          Right = "None";
          BottomRight = "None";
          Bottom = "None";
          BottomLeft = "None";
          Left = "None";
          TopLeft = "None";
        };
        "kwinrc".Effect-PresentWindows.BorderActivate = "9";
        "kwinrc".Effect-DesktopGrid.BorderActivate = "9";
        "kwinrc".TabBox.BorderActivate = "9";

        # Geometry Change: animates windows that are moved/resized by
        # programs or scripts (e.g. Krohnkite re-tiling). You enabled this
        # via System Settings > Window Management > Desktop Effects.
        "kwinrc".Plugins.kwin4_effect_geometry_changeEnabled = true;
        "kwinrc".Effect-kwin4_effect_geometry_change.Duration = 500;
        "kscreenrc".Config.autoRotate = false;
        "ksmserverrc".General.confirmLogout = false;

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
  };
}

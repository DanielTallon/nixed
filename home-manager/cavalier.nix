# /.dotfiles/home-manager/cavalier.nix
{ ... }:
{
  flake.modules.nixos.cavalier = { config, lib, pkgs, ... }:
    let
      cfg = config.custom.cavalier;
    in
    {
      # 1. Define Options
      options.custom.cavalier = {
        enable = lib.mkEnableOption "Cavalier audio visualizer";

        opacity = {
          foreground = lib.mkOption {
            type = lib.types.str;
            default = "ff"; # Fully opaque
            description = "Hex alpha channel for foreground (00-ff).";
          };
          background = lib.mkOption {
            type = lib.types.str;
            default = "01"; # Semi-transparent
            description = "Hex alpha channel for background (00-ff).";
          };
        };

        colors = {
          foreground = lib.mkOption {
            type = lib.types.str;
            default = "3584e4"; # Blue
            description = "6-digit RGB hex color for foreground (no alpha — see opacity.*).";
          };
          background = lib.mkOption {
            type = lib.types.str;
            default = "1e1e2e"; # Dark Blue
            description = "6-digit RGB hex color for background (no alpha — see opacity.*).";
          };
        };
      };

      #---Implement Configurations---
      config = lib.mkIf cfg.enable {
        # Home Manager Implementation (via the NixOS home-manager module's
        # sharedModules option, so this stays a nixos-class aspect)
        home-manager.sharedModules = [
          {
            programs.cavalier = {
              enable = true;
              settings.general = {
                # 100 total bars, stereo mode mirrors L/R -> 50 pairs.
                # If Stereo were false this would need to be 100 instead.
                BarPairs = 50;

                Borderless = true;
                AutohideHeader = true;

                # NoiseReduction is a float 0.15-0.95 per Cavalier's source;
                NoiseReduction = 0.80;

                # 3 = Bars, confirmed by round-tripping through Cavalier's own
                # Preferences UI and reading the resulting config.json.
                Mode = 3;

                ColorProfiles = [
                  {
                    Name = "Dendritic Profile";
                    # Construct aarrggbb from options
                    FgColors = [ "#${cfg.opacity.foreground}${cfg.colors.foreground}" ];
                    BgColors = [ "#${cfg.opacity.background}${cfg.colors.background}" ];
                    Theme = 1;
                  }
                ];
                ActiveProfile = 0;
              };
            };
          }
        ];

        # Optional: System-wide package availability (if not using HM packages)
        # environment.systemPackages = [ pkgs.cavalier ];
      };
    };
}

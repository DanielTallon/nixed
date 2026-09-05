# /.dotfiles/home-manager/konsole.nix
{
  flake.modules.homeManager.konsole = { config, pkgs, lib, ... }:
    let
      # Powerline glyphs, decoded from \u escapes so they survive as plain ASCII in this file
      roundedLeftCap = builtins.fromJSON ''"\ue0b6"''; # rounded left cap (start of prompt)
      pointRightCap = builtins.fromJSON ''"\ue0b0"''; # solid right-pointing triangle (connector)
      nixosIcon = builtins.fromJSON ''"\uf313"''; # nf-linux-nixos glyph
    in
    {
      # --- Konsole: launch with fish default ---
      programs.konsole = {
        enable = true;
        defaultProfile = "Fish";

        # Konsole's real opacity/blur toggle lives in the color scheme file,
        # not in konsole.conf. This clones Breeze and adds the two keys.
        customColorSchemes.BreezeTransparent = {
          General = {
            Anchor = "0.5,0.5";
            Blur = true; # per-window blur on/off; strength comes from kwin.effects.blur.strength in plasma.nix
            ColorRandomization = false;
            Description = "Breeze (transparent)";
            FillStyle = "Tile";
            Opacity = 0.75; # 0.0 (fully transparent) - 1.0 (fully opaque)
            WallpaperFlipType = "NoFlip";
            WallpaperOpacity = .80;
          };
          #RGB — three comma-separated integers from 0–255, in Red,Green,Blue order. So "35,38,39" is rgb(35, 38, 39), a dark near-black gray
          Foreground.Color = "252,252,252";
          ForegroundFaint.Color = "239,240,241";
          ForegroundIntense.Color = "61,174,233";
          Background.Color = "35,38,39";
          BackgroundFaint.Color = "49,54,59";
          BackgroundIntense.Color = "0,0,0";
          Color0.Color = "35,38,39";
          Color0Faint.Color = "49,54,59";
          Color0Intense.Color = "127,140,141";
          Color1.Color = "127,140,141";
          Color1Faint.Color = "120,50,40";
          Color1Intense.Color = "192,57,43";
          Color2.Color = "17,209,22";
          Color2Faint.Color = "23,162,98";
          Color2Intense.Color = "28,220,154";
          Color3.Color = "246,116,0";
          Color3Faint.Color = "182,86,25";
          Color3Intense.Color = "253,188,75";
          Color4.Color = "29,153,243";
          Color4Faint.Color = "27,102,143";
          Color4Intense.Color = "61,174,233";
          Color5.Color = "155,89,182";
          Color5Faint.Color = "97,74,115";
          Color5Intense.Color = "142,68,173";
          Color6.Color = "26,188,156";
          Color6Faint.Color = "24,108,96";
          Color6Intense.Color = "22,160,133";
          Color7.Color = "252,252,252";
          Color7Faint.Color = "99,104,109";
          Color7Intense.Color = "255,255,255";
        };

        profiles.default = {
          colorScheme = "BreezeTransparent";
          font = {
            name = "JetBrainsMono Nerd Font";
            size = 13;
          };
          extraConfig."General" = {
            TerminalMargin = 10; #Padding around the border. Was 20
          };
          extraConfig."Scrolling" = {
            ScrollBarPosition = 2; # 0 = left, 1 = right, 2 = hidden
          };
        };
        profiles.Fish = {
          command = "${pkgs.fish}/bin/fish";
          colorScheme = "BreezeTransparent";
          font = {
            name = "JetBrainsMono Nerd Font";
            size = 13;
          };
          extraConfig."General" = {
            TerminalColumns = 151;
            TerminalRows = 43;
            TerminalMargin = 10; #Padding around the border. Was 20
          };
          extraConfig."Scrolling" = {
            ScrollBarPosition = 2; # 0 = left, 1 = right, 2 = hidden
          };
        };
      };

      # --- Oh My Posh Ricing ---
      programs.oh-my-posh = {
        enable = true;
        enableFishIntegration = true;
        settings = {
          version = 2;
          final_space = true;
          blocks = [
            {
              type = "prompt";
              alignment = "left";

              #---Pill Settings---
              segments = [
                {
                  type = "text";
                  style = "diamond";
                  foreground = "#ffffff";
                  background = "#8B008B";
                  leading_diamond = roundedLeftCap;
                  powerline_symbol = pointRightCap;
                  template = "  ${nixosIcon} ";
                }
                {
                  type = "time";
                  style = "powerline";
                  foreground = "#ffffff";
                  background = "#064e40";
                  powerline_symbol = pointRightCap;
                  template = "  {{ .CurrentDate | date \"3:04\" }} ";
                }
                {
                  type = "path";
                  style = "powerline";
                  foreground = "#ffffff";
                  background = "#CC5500";
                  powerline_symbol = pointRightCap;
                  template = "  {{ .Path }} ";
                }
              ];
            }
          ];
        };
      };
    };
}

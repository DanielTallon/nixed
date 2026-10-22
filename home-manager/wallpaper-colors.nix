# /.dotfiles/home-manager/wallpaper-colors.nix
#---Desktop colors from the wallpaper---
# One switch, useMatugen below:
#   false - Plasma's own "accent color from wallpaper": highlights, selection
#           and focus follow the wallpaper, everything else stays Breeze Dark.
#   true  - matugen (run by the wallpaper picker on every wallpaper it sets)
#           makes a whole dark color scheme from the wallpaper: window, view,
#           button, header, selection and title-bar colors, plus the picker's
#           own UI. Always dark; it never switches you to a light scheme.
#
# After changing it: nh os switch, then log out and back in. Plasma only picks
# the change up at login (the matching startup script below runs once).
{
  flake.modules.homeManager.wallpaperColors = { config, pkgs, lib, inputs, ... }:
  let
    useMatugen = true;

    system = pkgs.stdenv.hostPlatform.system;
    wallpaperpicker = inputs.nix-packages.packages.${system}.wallpaperpicker;
    schemeDir = "${config.xdg.dataHome}/color-schemes";

    kwriteconfig = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
    kreadconfig = "${pkgs.kdePackages.kconfig}/bin/kreadconfig6";
    applyColorScheme = "${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-colorscheme";

    # A matugen color role as KDE writes colors ("r,g,b").
    c = role: "{{colors.${role}.default.red}},{{colors.${role}.default.green}},{{colors.${role}.default.blue}}";

    # One [Colors:*] group. The negative/neutral/positive colors are Breeze
    # Dark's, so errors and warnings still look like errors and warnings.
    colorGroup = name: bg: alt: ''
      [Colors:${name}]
      BackgroundNormal=${c bg}
      BackgroundAlternate=${c alt}
      DecorationFocus=${c "primary"}
      DecorationHover=${c "primary"}
      ForegroundNormal=${c "on_surface"}
      ForegroundInactive=${c "on_surface_variant"}
      ForegroundActive=${c "primary"}
      ForegroundLink=${c "primary"}
      ForegroundVisited=${c "tertiary"}
      ForegroundNegative=218,68,83
      ForegroundNeutral=246,116,0
      ForegroundPositive=39,174,96
    '';

    # A Plasma color scheme in matugen's template syntax, laid out like
    # Breeze Dark (ColorEffects copied from it).
    kdeTemplate = pkgs.writeText "matugen-kde.colors" ''
      [ColorEffects:Disabled]
      Color=56,56,56
      ColorAmount=0
      ColorEffect=0
      ContrastAmount=0.65
      ContrastEffect=1
      IntensityAmount=0.1
      IntensityEffect=2

      [ColorEffects:Inactive]
      ChangeSelectionColor=true
      Color=112,111,110
      ColorAmount=0.025
      ColorEffect=2
      ContrastAmount=0.1
      ContrastEffect=2
      Enable=false
      IntensityAmount=0
      IntensityEffect=0

      ${colorGroup "Window" "surface_container" "surface_container_high"}
      ${colorGroup "View" "surface" "surface_container_low"}
      ${colorGroup "Button" "surface_container_high" "surface_container_highest"}
      ${colorGroup "Header" "surface_container" "surface_container_low"}
      ${colorGroup "Header][Inactive" "surface_container_low" "surface_container"}
      ${colorGroup "Tooltip" "surface_container_highest" "surface_container_high"}
      ${colorGroup "Complementary" "surface_container_lowest" "surface_container"}
      [Colors:Selection]
      BackgroundNormal=${c "primary"}
      BackgroundAlternate=${c "primary_container"}
      DecorationFocus=${c "primary"}
      DecorationHover=${c "primary"}
      ForegroundNormal=${c "on_primary"}
      ForegroundInactive=${c "on_primary"}
      ForegroundActive=${c "on_primary"}
      ForegroundLink=${c "on_primary"}
      ForegroundVisited=${c "on_primary"}
      ForegroundNegative=176,55,69
      ForegroundNeutral=198,92,0
      ForegroundPositive=23,104,57

      [General]
      ColorScheme=Matugen
      Name=Matugen

      [KDE]
      contrast=4

      [WM]
      activeBackground=${c "surface_container"}
      activeBlend=${c "on_surface"}
      activeForeground=${c "on_surface"}
      inactiveBackground=${c "surface_container_low"}
      inactiveBlend=${c "on_surface_variant"}
      inactiveForeground=${c "on_surface_variant"}
    '';

    # plasma-apply-colorscheme does nothing when asked for the scheme that's
    # already in use, even if its file has changed, so take turns between
    # Matugen and a copy of it named MatugenAlt.
    applyMatugenScheme = pkgs.writeShellScript "apply-matugen-colorscheme" ''
      if [[ $(${kreadconfig} --file kdeglobals --group General --key ColorScheme) == Matugen ]]; then
        ${pkgs.gnused}/bin/sed -e 's/^ColorScheme=Matugen$/ColorScheme=MatugenAlt/' \
          -e 's/^Name=Matugen$/Name=Matugen (alt)/' \
          "${schemeDir}/Matugen.colors" > "${schemeDir}/MatugenAlt.colors"
        exec ${applyColorScheme} MatugenAlt
      fi
      exec ${applyColorScheme} Matugen
    '';
  in
  {
    programs.plasma.configFile."kdeglobals".General.accentColorFromWallpaper = !useMatugen;

    xdg.configFile."matugen/config.toml" = lib.mkIf useMatugen {
      text = ''
        [config]

        [templates.plasma]
        input_path = "${kdeTemplate}"
        output_path = "${schemeDir}/Matugen.colors"
        post_hook = "${applyMatugenScheme}"

        [templates.wallpaperpicker]
        input_path = "${wallpaperpicker}/share/wallpaperpicker/extras/matugen/quickshell.json.hbs"
        output_path = "${config.xdg.configHome}/wallpaperpicker/colors/Colors.json"
      '';
    };

    # Runs once at the first login after the switch changes (its text differs
    # between the two settings), after plasma-manager's own theme script.
    programs.plasma.startup.startupScript."wallpaper-colors" = {
      priority = 2;
      text =
        if useMatugen then ''
          # A leftover wallpaper accent would tint the scheme's own highlight.
          ${kwriteconfig} --file kdeglobals --group General --key AccentColor --delete
          # The current wallpaper's scheme now, rather than at the next one picked.
          if [ -e "$HOME/.cache/current_wallpaper" ]; then
            ${pkgs.matugen}/bin/matugen image "$HOME/.cache/current_wallpaper" --source-color-index 0
          fi
        '' else ''
          ${applyColorScheme} ${config.programs.plasma.workspace.colorScheme}
          # Back to the picker's built-in colors.
          rm -f "${config.xdg.configHome}/wallpaperpicker/colors/Colors.json"
        '';
    };
  };
}

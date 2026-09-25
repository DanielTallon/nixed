# /.dotfiles/modules/krohnkite.nix
{
  flake.modules.homeManager.krohnkite = { pkgs, config, ... }: {
    home.packages = [ pkgs.kdePackages.krohnkite ];
    programs.plasma.configFile = {
      "kwinrc"."Plugins"."krohnkiteEnabled" = true;

      #NOTE: Krohnkite always start on Three Column layout, on every screen/activity/

      "kwinrc"."Script-krohnkite"."screenDefaultLayout" = ":threecolumn";

      # Float Steam and its Friends List window instead of tiling them.
      # Both share the "steam" window class (resourceClass), so one entry
      # covers both.
      "kwinrc"."Script-krohnkite"."floatingClass" = "steam,Glava,NickvisionCavalier.GNOME";

      # Gaps: between tiles, and between tiles and the screen edge.
      # All values in px; tune to taste.
      "kwinrc"."Script-krohnkite"."tileLayoutGap" = 10;
      "kwinrc"."Script-krohnkite"."screenGapLeft" = 20;
      "kwinrc"."Script-krohnkite"."screenGapRight" = 20;
      "kwinrc"."Script-krohnkite"."screenGapTop" = 20;
      "kwinrc"."Script-krohnkite"."screenGapBottom" = 20;
      "kwinrc"."Script-krohnkite"."screenGapBetween" = 10; # the actual gap between tiled windows

      # Layout cycle order (Monocle -> Three Column -> Tile)
      "kwinrc"."Script-krohnkite"."monocleLayoutOrder" = 1;
      "kwinrc"."Script-krohnkite"."threeColumnLayoutOrder" = 2;
      "kwinrc"."Script-krohnkite"."tileLayoutOrder" = 3;

      # Size (%) of a window when it is the only one on the screen
      "kwinrc"."Script-krohnkite"."soleWindowWidth" = 75;
      "kwinrc"."Script-krohnkite"."soleWindowHeight" = 95;

      "kwinrc"."Script-krohnkite"."limitTileWidthRatio" = 1;
      "kwinrc"."Script-krohnkite"."notificationDuration" = 500;
    };

    # Meta+Return launches Konsole (see konsole.nix); unbind Krohnkite's
    # default "Set master" so the two don't fight over it.
    programs.plasma.shortcuts.kwin."KrohnkiteSetMaster" = [ ];
  };
}

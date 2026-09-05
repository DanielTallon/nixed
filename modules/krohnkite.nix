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
    };
  };
}

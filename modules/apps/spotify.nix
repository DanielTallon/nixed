# /.dotfiles/modules/apps/spotify.nix
# Spotify, patched by spicetify-nix: ads blocked, Sleek theme in its Dracula
# colors. This installs Spotify itself, so don't also list `spotify` in
# packages.nix.
#
# If Spotify updates and an extension stops working, update the
# spicetify-nix input (or pin it to the last good rev in flake.nix).
{ inputs, ... }:
{
  flake.modules.homeManager.spotify = { pkgs, ... }:
    let
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      imports = [ inputs.spicetify-nix.homeManagerModules.default ];

      programs.spicetify = {
        enable = true;

        theme = spicePkgs.themes.sleek;
        colorScheme = "Dracula";

        enabledExtensions = with spicePkgs.extensions; [
          adblockify   # blocks audio, video and banner ads
          hidePodcasts # music only on the home page
          shuffle      # shuffle+: a real random shuffle instead of Spotify's weighted one
        ];
      };
    };
}

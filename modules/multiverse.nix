# /.dotfiles/modules/multiverse.nix

# NOTE: nixpkgs-multiverse itself has `inputs = { }` — it fetches revisions
# lazily via builtins.fetchTree, so adding it does not pull in a second
# nixpkgs eagerly the way a manual pin would.

{ inputs, ... }:
{
  flake.modules.nixos.multiverse = { pkgs, ... }: {
    nixpkgs.overlays = [
      (final: _prev: {
        # pkgs.multiverse.at "24.11"              -> full pkgs set pinned to a release
        # pkgs.multiverse.at "2022-03-15"          -> newest revision on/before a date
        # pkgs.multiverse.at "aae12a743f75"        -> full pkgs set pinned to a commit
        # pkgs.multiverse.tip                      -> newest indexed revision
        # pkgs.multiverse.versions.python3."3.8.9" -> a single package at an exact version
        # pkgs.multiverse.versionsOf "python3"     -> list every version ever indexed
        multiverse = inputs.multiverse.multiverse.${final.stdenv.hostPlatform.system};
      })
    ];
  };
}

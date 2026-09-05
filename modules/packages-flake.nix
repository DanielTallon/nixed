# /.dotfiles/modules/packages-flake.nix
# NOTE: This is what registers kenku-fm as packages.kenku-fm.
# It lets you `nix build .#kenku-fm` directly.
# NOTE: Do not delete packages-flake.nix and keep _kenku-fm/default.nix; the derivation would be orphaned, so nix build .#kenku-fm just errors with "flake output attribute not found."
# So: keep both, together — they're not two independent files, they're one working feature split across a "what" (default.nix) and a "how it's exposed" (packages-flake.nix).
# NOTE: The underscore prefix on _kenku-fm actively prevents Dendritic's import-tree from picking it up automatically, so without this file there's no other path by which it gets wired in.


{ inputs, ... }:
{
  perSystem = { system, ... }:
    let
      pkgs-stable = import inputs.nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages.kenku-fm = pkgs-stable.callPackage ./_kenku-fm/default.nix { };
    };
}

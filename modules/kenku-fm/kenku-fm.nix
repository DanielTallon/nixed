# /.dotfiles/modules/kenku-fm/kenku-fm.nix
{ inputs, ... }:
{
  flake.modules.nixos.kenkuFm = { pkgs, ... }: {
    environment.systemPackages = [
      inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.kenku-fm
    ];
  };
}

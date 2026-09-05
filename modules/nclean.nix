# /.dotfiles/modules/nclean.nix
{
  flake.modules.nixos.nclean = { inputs, pkgs, ... }: {
    environment.systemPackages = [
      inputs.nclean.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}

#/.dotfiles/home-manager/lgl-papercutter.nix
{ inputs, ... }:
{
  flake.modules.homeManager.lglPapercutter = { pkgs, ... }: {
    home.packages = [
      inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.lgl-papercutter
    ];
  };
}

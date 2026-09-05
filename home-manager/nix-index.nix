#/.dotfiles/home-manager/nix-index.nix
{ inputs, ... }:
{
  flake.modules.homeManager.nix-index = { pkgs, ... }: {
    imports = [ inputs.nix-index-database.homeModules.nix-index ];

    programs.nix-index.enable = true;
    programs.nix-index.enableFishIntegration = true;
    programs.nix-index-database.comma.enable = true;
    programs.command-not-found.enable = false;
  };
}

# /.dotfiles/modules/flatpak.nix
{
  flake.modules.nixos.flatpak = { inputs, pkgs, ... }: {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak.enable = true;

    services.flatpak.packages = [
      "io.github.kolunmi.Bazaar"

      {
        appId = "io.github.chrisdkn.AmethystModManager";
        bundle = toString (pkgs.fetchurl {
          url = "https://github.com/ChrisDKN/Amethyst-Mod-Manager/releases/download/v1.3.5/AmethystModManager.flatpak";
          sha256 = "sha256-eyNX91+Z6FIsEBMKHXPS460Bpw89rUvIzqHc4VgaaKU=";
        });
      }
    ];
  };
}

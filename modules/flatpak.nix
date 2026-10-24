# /.dotfiles/modules/flatpak.nix
{
  flake.modules.nixos.flatpak = { inputs, ... }: {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak.enable = true;

    services.flatpak.update.auto = {
      enable = true;
      onCalendar = "daily";
    };

    services.flatpak.packages = [
      "io.github.kolunmi.Bazaar"
    ];
  };
}

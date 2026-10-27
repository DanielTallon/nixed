# /.dotfiles/modules/desktop/flatpak.nix
# Flatpak via nix-flatpak, with Discover limited to its Flatpak backend.
{
  flake.modules.nixos.flatpak = { inputs, pkgs, ... }: {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak.enable = true;
    services.packagekit.enable = false;

    services.flatpak.update.auto = {
      enable = true;
      onCalendar = "daily";
    };

    services.flatpak.packages = [
      "io.github.kolunmi.Bazaar"
    ];

    environment.systemPackages = with pkgs; [
      flatpak
      (kdePackages.discover.overrideAttrs (_old: {
        postFixup = ''
          wrapProgram $out/bin/plasma-discover \
            --add-flags "--backends flatpak"
        '';
      }))
    ];
  };
}

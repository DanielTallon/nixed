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

    # The timer is Persistent, so after a missed day it runs right at boot, before DNS works, and fails
    # (Restart=on-failure fixes it a minute later, but a switch in that minute reports it as failed).
    systemd.services.flatpak-managed-install-timer = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
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

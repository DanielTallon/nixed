# /.dotfiles/modules/de.nix (Desktop Environment)
{
  flake.modules.nixos.desktopEnvironment = { config, lib, pkgs, ... }: {
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;
    security.pam.services.sddm.kwallet.enable = true;

    #environment.systemPackages = with pkgs; [
    #  kdePackages.konsole
    #  kdePackages.kate
    #];

    # --- Alternative Desktop Environments (commented out) ---
    # GNOME
    # services.displayManager.gdm.enable = true;
    # services.desktopManager.gnome.enable = true;
    # environment.systemPackages = with pkgs; [ gnome-tweaks ];

    # XFCE
    # services.xserver.desktopManager.xfce.enable = true;
    # services.displayManager.defaultSession = "xfce";
    # environment.systemPackages = with pkgs; [ xfce.thunar ];

    # COSMIC
    # services.desktopManager.cosmic.enable = true;
    # services.displayManager.cosmic-greeter.enable = true;
  };
}

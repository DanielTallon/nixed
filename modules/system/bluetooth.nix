# /.dotfiles/modules/system/bluetooth.nix
{
  flake.modules.nixos.bluetooth = {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        Experimental = true;        # AirPods battery level in Plasma
        # ControllerMode = "bredr"; # uncomment if AirPods won't connect or keep dropping
      };
    };

    services.blueman.enable = true;  # pairing GUI; skip it if you use GNOME or KDE
  };
}

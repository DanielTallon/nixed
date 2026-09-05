# /.dotfiles/modules/bootloader.nix
# Limine bootloader config.
{
  flake.modules.nixos.bootloader = { config, lib, pkgs, ... }: {
    boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.limine = {
      enable = true;
      validateChecksums = true;
      maxGenerations = 10;

      extraConfig = ''
        timeout: 3
        remember_last_entry: yes
        term_font_scale: 2x2
      '';

      style = {
        wallpapers = [ ./assets/boot_wallpaper.png ];
        wallpaperStyle = "centered";
      };
    };

    boot.initrd.kernelModules = lib.optionals config.hasNvidia [ "nvidia" "nvidia_modeset" "nvidia_drm" "nvidia_uvm" ];
    boot.plymouth = {
      enable = true;

      #---Rings Theme
      theme = "rings"; # pick any theme you like from https://github.com/adi1090x/plymouth-themes
      themePackages = with pkgs; [
        (adi1090x-plymouth-themes.override { selected_themes = [ "rings" ]; })
      ];

    };
    boot.consoleLogLevel = 0;
    boot.initrd.verbose = false;
    boot.kernelParams = [
      "quiet"
      "splash"
      "udev.log_level=3"
      "usbcore.autosuspend=-1"
    ] ++ lib.optionals config.hasNvidia [
      "nvidia_drm.modeset=1"
      "nvidia_drm.fbdev=1"
    ];

    boot.tmp.cleanOnBoot = true;
  };
}

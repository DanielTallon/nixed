# Written by nixed-install (see modules/installer.nix in the nixed repo).
#
# This is a throwaway first-boot system, not the real config. It only has
# to boot, get online, and run stage 2 (installer/stage2.sh), which clones
# the repo to ~/.dotfiles, builds the real host with `nixos-rebuild boot`
# and reboots into it. After that, nothing here is used any more.
#
# The two "stage 2 only" settings below (tty1 autologin, passwordless sudo)
# are why stage 2 can run unattended. They disappear with the real config.
{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./locale.nix # timezone, language, keyboard; stage 2 carries it into the repo
  ];

  boot.loader.limine = {
    enable = true;
    efiSupport = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "@HOST@";
  networking.networkmanager.enable = true;

  users.users."@USER@" = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # --- Stage 2 only ---
  services.getty.autologinUser = "@USER@";
  security.sudo.wheelNeedsPassword = false;

  # Runs stage 2 once, on tty1, while the marker file exists.
  programs.bash.loginShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && [ -e /var/lib/nixed/stage2 ]; then
      bash /etc/nixos/nixed-stage2.sh
    fi
  '';

  # Compressed swap in RAM, so a big stage 2 build slows down instead of
  # running out of memory and hanging (the base system has no swap otherwise).
  zramSwap.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = [ pkgs.git pkgs.curl ];

  system.stateVersion = "@STATEVERSION@";
}

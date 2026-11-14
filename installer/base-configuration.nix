# Written by nixed-install (see modules/installer.nix in the nixed repo).
#
# This is a throwaway first-boot system, not the real config. It only has
# to boot, get online, and run stage 2 (installer/stage2.sh), which clones
# the repo to ~/.dotfiles, builds the real host with `nixos-rebuild boot`
# and reboots into it. After that, nothing here is used any more.
#
# The two "stage 2 only" settings below (tty1 autologin, passwordless sudo)
# are why stage 2 can run unattended. They disappear with the real config.
{ lib, pkgs, ... }:
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

  networking.hostName = "nixos";
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

  # Same console font the installer picked for this screen (empty = default),
  # so stage 2 is as readable as stage 1 was.
  console.font = lib.mkIf ("@FONT@" != "") "@FONT@";
  console.packages = lib.mkIf ("@FONT@" != "") [ pkgs.terminus_font ];

  # Compressed swap in RAM, so a big stage 2 build slows down instead of
  # running out of memory and hanging (the base system has no swap otherwise).
  zramSwap.enable = true;

  # Stage 2 compiles some big packages from source when they aren't in the
  # binary cache (rustdesk, localsend). With nix's defaults it ran 8 builds
  # at once, each using every core, and an E14 laptop ran out of memory:
  # udev and journald died and the build hung. Two builds at a time, two
  # cores each, is slower but fits in a laptop's RAM. Only this throwaway
  # base system uses these limits; the real config keeps nix's defaults.
  nix.settings.max-jobs = 2;
  nix.settings.cores = 2;

  # If memory still runs out, kill a compiler (the build fails and stage 2
  # says how to retry) instead of letting the kernel take out system
  # services and hang the machine. Never pick nix-daemon (it would take every
  # build with it) or the services that died last time.
  services.earlyoom = {
    enable = true;
    extraArgs = [
      "--prefer" "^(cc1|cc1plus|rustc|ld|ld.lld|clang|dart|node)$"
      "--avoid" "^(systemd|systemd-udevd|systemd-journal|nix-daemon|NetworkManager)$"
    ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = [ pkgs.git pkgs.curl ];

  system.stateVersion = "@STATEVERSION@";
}

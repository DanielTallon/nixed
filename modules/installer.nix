# /.dotfiles/modules/installer.nix
#
# Two-stage install from the NixOS minimal ISO. No Calamares:
#
#   nmtui          # get online (skip on wired)
#   nix --extra-experimental-features 'nix-command flakes' \
#     run github:DanielTallon/nixed#install
#
# Stage 1 (this app, installer/nixed-install.sh), on the live ISO:
#   - asks: host, username, password
#   - detects timezone, language and keyboard from your IP, shows them on a
#     review screen where each can be changed
#   - you pick the disk (the ISO's own disk is hidden, disks with Windows or
#     NTFS on them are refused) and type its name to confirm
#   - disko erases it: 3G FAT32 /boot + btrfs / (installer/disk-layout.nix)
#   - installs a small base system: your user, NetworkManager, Limine,
#     flakes, and a first-boot hook (installer/base-configuration.nix)
# Shut down, remove the media, power on. Stage 2 (installer/stage2.sh) runs
# by itself on tty1: it runs the normal bootstrap app (modules/bootstrap.nix),
# which clones this repo to ~/.dotfiles, carries over hardware/locale/GPU/Windows detection and runs
# `nixos-rebuild boot`. Then it reboots into the real config.
#
# The heavy build happens in stage 2 on the real disk, not in the live
# ISO's RAM, which is what made one-shot disko-install run out of memory.
#
# Also builds a custom installer ISO with `nixed-install` already on it:
#   nix build .#installer-iso    (result/iso/*.iso)
#
# Testing a branch: NIXED_REF=<branch> nix run 'github:DanielTallon/nixed/<branch>#install'
# (NIXED_REF is what stage 2 clones and builds; NIXED_REPO=<git url> for a fork.)
{ inputs, lib, config, ... }:
let
  mkInstaller = pkgs:
    let
      # Only the UTF-8 locale names from glibc's list, e.g. "en_US.UTF-8".
      # Pulled out of glibc's source so the ISO doesn't need the 200+ MB
      # glibcLocales package just to check a name.
      locales = pkgs.runCommand "glibc-utf8-locales.txt" { } ''
        tar -xf ${pkgs.glibc.src} --wildcards '*/localedata/SUPPORTED' -O \
          | grep -o '^[^/ ]*\.UTF-8/UTF-8' | cut -d/ -f1 | sort -u > $out
      '';
      stable = inputs.nixpkgs-stable;
    in
    pkgs.writeShellApplication {
      name = "nixed-install";
      runtimeInputs = with pkgs; [
        gum
        jq
        curl
        mkpasswd
        util-linux
        gawk
        gnused
        gnugrep
        nixos-install-tools
        inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
      ];
      text = ''
        LAYOUT=${../installer/disk-layout.nix}
        TEMPLATES=${../installer}
        ZONEINFO=${pkgs.tzdata}/share/zoneinfo
        LOCALES=${locales}
        XKB_RULES=${pkgs.xkeyboard-config}/share/X11/xkb/rules/base.lst
        BASE_NIXPKGS=${stable}
        BASE_STATE=${lib.versions.majorMinor stable.lib.version}
        DEFAULT_REPO=https://github.com/DanielTallon/nixed.git
      '' + builtins.readFile ../installer/nixed-install.sh;
    };
in
{
  perSystem = { pkgs, ... }: {
    packages.nixed-install = mkInstaller pkgs;
    apps.install = {
      type = "app";
      meta.description = "Erase a disk and install this config from the NixOS minimal ISO";
      program = lib.getExe (mkInstaller pkgs);
    };
  };

  # Custom installer ISO: the stock minimal ISO plus nixed-install.
  flake.nixosConfigurations.installer = inputs.nixpkgs-stable.lib.nixosSystem {
    modules = [
      "${inputs.nixpkgs-stable}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      ({ pkgs, ... }: {
        nixpkgs.hostPlatform = "x86_64-linux";
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        environment.systemPackages = [ (mkInstaller pkgs) ];
        isoImage.appendToMenuLabel = " (nixed installer)";
        boot.zfs.forceImportRoot = false; # silences the 26.11 default-change warning
        services.getty.helpLine = lib.mkAfter ''

          To install nixed: connect with `nmtui` (Wi-Fi only), then run `nixed-install`.
        '';
      })
    ];
  };

  flake.packages.x86_64-linux.installer-iso =
    config.flake.nixosConfigurations.installer.config.system.build.isoImage;
}

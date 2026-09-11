# /.dotfiles/modules/disko.nix
#
# Declarative disk layout for the dedicated NixOS disk.
# GPT + 3G FAT32 ESP + a single btrfs root, no subvolume split
# (home-manager isn't separate, so there's no reason to isolate /home).
#
# STATUS: kept INERT — not wired into any host's imports in hosts.nix.
# This is a "break glass in case of emergency" config, not something
# used in day-to-day rebuilds. Do NOT import this aspect while the
# target disk is your live, mounted root — it will collide with
# hardware-configuration.nix's fileSystems."/" entry (conflicting
# `device` definitions), because NixOS eval derives a fileSystems
# entry from disko.devices regardless of whether the disk has
# actually been partitioned yet.
#
# FULL STEP-BY-STEP REINSTALL RUNBOOK: see disko-RUNBOOK.md in this
# same directory. That file is verified working end-to-end (VM tested,
# Sept 2026) and is meant to be read and copy-pasted from directly —
# this file stays pure Nix so it always evaluates cleanly, even years
# from now under stress.
{
  flake.modules.nixos.disko = { ... }: {
    # IMPORTANT: replace `device` below with a stable by-id path before
    # running, e.g. `/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_..._1`.
    # Get it with: ls -l /dev/disk/by-id/ | grep -v part
    disko.devices = {
      disk = {
        main = {
          device = "/dev/disk/by-id/REPLACE_ME";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                type = "EF00";
                size = "3G";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };

              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "btrfs";
                  mountpoint = "/";
                  mountOptions = [ "compress=zstd" "noatime" ];
                  extraArgs = [ "-f" "-L" "nixos" ];
                };
              };
            };
          };
        };
      };
    };
  };
}

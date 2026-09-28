# /.dotfiles/installer/disk-layout.nix
# Disko layout used by `nixed-install` (modules/installer.nix). Same layout
# as INSTALL.md's manual table: GPT, 3G FAT32 ESP on /boot, btrfs on / for
# the rest. No subvolumes (home-manager lives in the NixOS config).
#
# `device` is passed in by the installer (disko --argstr device /dev/...),
# so nothing here names a real disk and it can't wipe one on its own.
#
# Lives outside modules/ on purpose: import-tree would try to load it as a
# flake-parts module.
{ device ? throw "disk-layout.nix: pass the target disk with --argstr device /dev/<disk>", ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "3G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-F" "32" "-n" "BOOT" ];
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "btrfs";
            extraArgs = [ "-f" "-L" "nixos" ];
            mountpoint = "/";
            mountOptions = [ "compress=zstd" "noatime" ];
          };
        };
      };
    };
  };
}

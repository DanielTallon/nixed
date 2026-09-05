# /.dotfiles/modules/disko.nix
# Declarative disk layout for the dedicated NixOS disk.
# GPT + 3G FAT32 ESP + a single btrfs root, no subvolume split
# (home-manager isn't separate, so there's no reason to isolate /home).
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

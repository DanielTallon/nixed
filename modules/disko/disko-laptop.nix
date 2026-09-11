# /.dotfiles/modules/disko-laptop.nix

{
  flake.modules.nixos.diskoLaptop = { ... }: {
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

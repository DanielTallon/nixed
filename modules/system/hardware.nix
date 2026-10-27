# /.dotfiles/modules/system/hardware.nix
# Machine-level bits that don't belong to a bigger feature.
{
  flake.modules.nixos.hardware = {
    # --- CPU MicroCode ---
    hardware.cpu.intel.updateMicrocode = true;

    #---Allow for reading backups from Windows ---
    boot.supportedFilesystems = [ "ntfs" ];

    # --- Printing ---
    services.printing.enable = true;

    # Disk write-back: fewer stalls during large writes (shader caches, game installs)
    boot.kernel.sysctl = {
      "vm.dirty_bytes" = 268435456;            # 256 MB
      "vm.dirty_background_bytes" = 67108864;  # 64 MB
      "vm.vfs_cache_pressure" = 50;
    };
  };
}

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

    # --- Drive health ---
    # smartd watches the drives' SMART data and warns (journal + wall
    # message) when one starts failing. `sudo smartctl -a /dev/nvme0n1`
    # shows a drive's report by hand.
    services.smartd.enable = true;

    # --- Firmware updates ---
    # fwupd fetches firmware from LVFS (NVMe drives, some peripherals).
    # Nothing installs on its own: `fwupdmgr refresh` then `fwupdmgr update`.
    services.fwupd.enable = true;

    # Disk write-back: fewer stalls during large writes (shader caches, game installs)
    boot.kernel.sysctl = {
      "vm.dirty_bytes" = 268435456;            # 256 MB
      "vm.dirty_background_bytes" = 67108864;  # 64 MB
      "vm.vfs_cache_pressure" = 50;
    };
  };
}

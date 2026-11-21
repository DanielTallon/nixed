# /.dotfiles/modules/system/hardware.nix
# Machine-level bits that don't belong to a bigger feature.
{
  flake.modules.nixos.hardware = { options, ... }: {
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

    # --- Log and crash dump cleanup ---
    # Cap the journal (was 1.2 GB) and delete crash dumps older than 3 days
    # (was 725 MB, mostly old Baloo crashes). Both ideas from CachyOS-Settings.
    # `coredumpctl list` shows what's crashed recently.
    # Unstable replaced journald.extraConfig with journald.settings; 26.05
    # only has extraConfig. Drop the else branch once stable has settings.
    services.journald =
      if options.services.journald ? settings
      then { settings.Journal.SystemMaxUse = "500M"; }
      else { extraConfig = "SystemMaxUse=500M"; };
    systemd.tmpfiles.rules = [
      "e /var/lib/systemd/coredump - - - 3d"
    ];

    # --- Faster shutdown ---
    # Wait 10s (default 90s) for a hung service or app before killing it at
    # shutdown/reboot (from CachyOS-Settings). Units that set their own timeout
    # keep it, e.g. libvirt-guests still gives VMs time to shut down cleanly.
    systemd.settings.Manager.DefaultTimeoutStopSec = "10s";
    # Unstable has systemd.user.settings; 26.05 only has user.extraConfig.
    # Drop the else branch once stable has settings.
    systemd.user =
      if options.systemd.user ? settings
      then { settings.Manager.DefaultTimeoutStopSec = "10s"; }
      else { extraConfig = "DefaultTimeoutStopSec=10s"; };

    # Disk write-back: fewer stalls during large writes (shader caches, game installs)
    boot.kernel.sysctl = {
      "vm.dirty_bytes" = 268435456;            # 256 MB
      "vm.dirty_background_bytes" = 67108864;  # 64 MB
      "vm.vfs_cache_pressure" = 50;
    };
  };
}

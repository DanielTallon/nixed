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
# ---------------------------------------------------------------------
# DISASTER-RECOVERY: ONE-COMMAND REINSTALL (desktop)
# ---------------------------------------------------------------------
# disko-install partitions, formats, mounts, runs nixos-install, and
# writes bootloader entries in a single step — no separate disko +
# nixos-install dance needed.
#
# Uses the public `nixed` repo (github.com/DanielTallon/nixed) for the
# initial install, since it needs no git auth on a bare live ISO. The
# handful of things stripped out during sanitizing (SSH allowed_signers,
# personal READMEs, real UUIDs in hardware-configuration.nix — the
# latter irrelevant here since disko replaces those anyway) get added
# back afterward from the private repo once you're booted and can
# authenticate normally. `nixed` is kept in sync with the private repo
# on every update, so it should always be current.
#
# 1. Boot a NixOS live ISO/installer with network access.
#
# 2. Confirm the target disk before running anything:
#      ls -l /dev/disk/by-id/ | grep -v part
#    On the desktop, the Windows dual-boot lives on a separate disk —
#    make sure it is NOT the one you point disko-install at.
#
# --- 2.5 --- #
#    Disk naming will likely differ. VMs commonly expose disks as /dev/vda (virtio)
#    or /dev/sda (SATA/IDE emulation) rather than /dev/nvme0n1.
#    Check with lsblk or ls -l /dev/disk/by-id/ inside the VM — virtio disks sometimes
#    don't populate /dev/disk/by-id/ the same way real NVMe drives do,
#    so you may just end up using /dev/vda directly for the test even though
#    your real hardware config uses a by-id path.
#
# 3. Run:
#      nix --extra-experimental-features "nix-command flakes" \
#        run 'github:nix-community/disko/latest#disko-install' -- \
#        --flake "github:DanielTallon/nixed#nixos" \
#        --disk main /dev/nvme0n1 \
#        --write-efi-boot-entries
#    (swap `/dev/nvme0n1` for the correct disk, ideally a `by-id` path
#    for reliability if multiple NVMe drives are present; `main`
#    must match the disk name used in this file's `disko.devices.disk`
#    attrset; `#nixos` must match nixed's flake nixosConfigurations
#    output name for this host — confirm it matches before relying on
#    this, since `nixed` and the private repo could drift)
#
# 4. Reboot into the fresh install (now running from `nixed`).
#
# 5. Sign into GitHub, clone the private repo somewhere, and copy back
#    the few personal bits that were stripped for `nixed` (SSH
#    allowed_signers, personal READMEs, etc. — see the private repo's
#    sanitizing notes for the exact diff). Once reconciled, either
#    switch `~/.dotfiles` over to the private repo as origin, or keep
#    running from `nixed` and just carry the personal bits as an
#    untracked/local overlay — whichever fits how you use the two
#    repos day to day.
#
# 6. Once booted, this `disko` aspect can be added to the host's
#    imports in hosts.nix, since disko.devices now matches reality.
#    At that point, strip the fileSystems ("/" and "/boot") and
#    swapDevices stanzas out of hardware-configuration.nix for this
#    host — disko is now the sole source of truth for those, and
#    leaving the old entries in reproduces the same device-conflict
#    error that prompted this note in the first place.
#
# See also: disko-laptop.nix for the laptop's equivalent layout/command.
# ---------------------------------------------------------------------
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

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
# DISASTER-RECOVERY: REINSTALL PLAN (desktop)
# ---------------------------------------------------------------------
# Tested via VM (Sept 2026) and deliberately kept simple after a long
# night discovering that `disko-install` (the all-in-one partition +
# format + nixos-install command) tries to build the FULL desktop
# closure (KDE, NVIDIA, Steam, Bottles, etc.) from inside the live
# ISO's constrained tmpfs/RAM environment — which repeatedly hit
# out-of-memory kills and tmpfs "no space left on device" errors, even
# with 25G+ of VM RAM and manual zram/tmpfs-resize workarounds. The
# actual disko partitioning step (the part unique to disko) worked
# fine in isolation; it was bundling the huge config build into the
# same constrained environment that caused every failure.
#
# Root cause avoided by this plan: never build the real desktop
# closure inside the live ISO. Partition with disko, install a
# minimal/default system with the graphical installer, reboot into a
# normal fully-booted system (no tmpfs ceiling, real RAM, real swap),
# THEN clone the real config and rebuild there.
#
# 1. Boot the NixOS graphical installer ISO.
#
# 2. Confirm the correct disk before touching anything:
#      lsblk
#      ls -l /dev/disk/by-id/ | grep -v part
#    On real hardware, prefer a `by-id` path over a raw device name
#    (e.g. /dev/nvme0n1) for reliability. On the desktop, the Windows
#    dual-boot lives on a SEPARATE disk — make sure it is NOT the one
#    disko targets.
#
# 3. Open a terminal from the installer and run disko in
#    PARTITION-ONLY mode against this file — this partitions, formats,
#    and mounts everything under /mnt, and does NOT run nixos-install
#    or build anything:
#      sudo nix --extra-experimental-features "nix-command flakes" \
#        run github:nix-community/disko -- --mode disko \
#        /path/to/disko.nix
#    (adjust the device in this file's `disko.devices.disk.main.device`
#    to the confirmed target before running — see step 2)
#
# 4. Launch the graphical installer as normal. Since /mnt is already
#    partitioned and mounted by disko, check whether the installer
#    detects and respects that existing layout, or wants to drive
#    partitioning itself — behavior may vary by installer version, so
#    confirm this live rather than assuming. Let it install its own
#    default minimal system using the disko'd partitions.
#
# 5. Reboot into the fresh minimal install.
#
# 6. Log into the new system normally (real RAM, no live-ISO
#    constraints). Sign into GitHub, clone the real config:
#      git clone <repo-url> ~/.dotfiles
#    (the public `nixed` mirror needs no auth and is kept in sync with
#    the private repo on every update, so it's a safe first pull if
#    GitHub auth isn't set up yet — reconcile personal bits like SSH
#    allowed_signers from the private repo afterward)
#
# 7. Rebuild the real config from the now-booted, unconstrained system:
#      cd ~/.dotfiles
#      sudo nixos-rebuild switch --flake .#nixos
#    (or `nh os switch` once nh itself is available) — the big closure
#    build happens HERE, not inside the live ISO, which is the whole
#    point of this split.
#
# 8. Once booted on the real config, this `disko` aspect can be added
#    to the host's imports in hosts.nix, since disko.devices now
#    matches reality. At that point, strip the fileSystems ("/" and
#    "/boot") and swapDevices stanzas out of hardware-configuration.nix
#    for this host — disko is now the sole source of truth for those,
#    and leaving the old entries in reproduces the original
#    device-conflict error that prompted this whole runbook.
#
# See also: disko-laptop.nix for the laptop's equivalent layout/plan.
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

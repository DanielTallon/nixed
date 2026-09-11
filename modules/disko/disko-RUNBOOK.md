# Disaster-Recovery Reinstall Plan (desktop) — VERIFIED WORKING

Fully tested end-to-end via VM (Sept 2026). Earlier attempts used
`disko-install` (an all-in-one partition+format+nixos-install command)
but that tries to build the FULL desktop closure (KDE, NVIDIA, Steam,
Bottles, etc.) from inside the live ISO's constrained tmpfs/RAM,
causing repeated OOM kills and tmpfs "no space" errors even with 25G+
VM RAM and manual zram/tmpfs-resize workarounds. This plan avoids that
entirely: disko only partitions (fast, no build), the graphical
installer does a minimal install, and the REAL closure build happens
only after reboot on a normal, unconstrained running system.

The corresponding `disko.devices` module lives in `disko.nix` next to
this file, kept INERT (not imported in `hosts.nix`) until actually
needed — importing it while the target disk is your live, mounted
root will collide with `hardware-configuration.nix`'s `fileSystems."/"`
entry (conflicting `device` definitions).

## 0. Confirm UEFI firmware

IMPORTANT: confirm the machine/VM firmware is UEFI, not legacy BIOS.
This layout uses a 3GB FAT32 ESP, which GRUB/systemd-boot can only use
in UEFI mode. On a VM, check virt-manager's Firmware setting before
booting. Installing under BIOS firmware fails at the bootloader step
with a GRUB "blocklists are UNRELIABLE" / "no BIOS Boot Partition"
error — confirmed by hitting this exact failure once before switching
the VM to UEFI.

## 1. Find the target drive

```
lsblk
```

On real hardware, prefer a stable identifier over a raw device name:

```
ls -l /dev/disk/by-id/ | grep -v part
```

You'll use this path (e.g.
`/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_..._1`) in place of
`/dev/vda` below for real hardware; `/dev/vda` is fine for VM testing
only. On the desktop, the Windows dual-boot lives on a SEPARATE disk —
make sure it is NOT the one targeted here.

## 2. Write disko.nix (standalone copy for the live installer)

```
mkdir -p /tmp/disko-test && cd /tmp/disko-test
cat > disko.nix << 'DISKOEOF'
{
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
}
DISKOEOF
```

Replace `/dev/disk/by-id/REPLACE_ME` with the actual device from step
1 before running the heredoc, or edit it after with `nano disko.nix`.

Note: this standalone copy is the bare `{ disko.devices = { ... }; }`
attrset only — no `flake.modules.nixos.disko = { ... }: { ... };`
wrapper. That wrapper is specific to how the real dotfiles repo
registers this as a flake module (Dendritic pattern); the disko CLI
tool run directly against a file wants the plain config, not a flake
module fragment.

## 3. Partition, format, and mount

No build, no closure — fast:

```
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- --mode disko \
  /tmp/disko-test/disko.nix
```

## 4. Sanity check

```
lsblk
df -h /mnt /mnt/boot
```

## 5. Graphical installer

Launch Calamares. At the partitioning step, choose **Manual
Partitioning**. The disko-created partitions should already be
visible:

- `vda1` (3G, vfat) → mount `/boot`, do **NOT** reformat
- `vda2` (rest, btrfs) → mount `/`, do **NOT** reformat

Pick the lightest/no desktop environment option if offered — the real
desktop config comes from the dotfiles rebuild afterward, so this
installer's own choice doesn't matter long-term.

Finish install, reboot, remove the ISO from the virtual drive.

## 6. After reboot: get git

Fresh installs may not have it yet:

```
nix-shell -p git
```

## 7. Clone the repo

```
git clone https://github.com/DanielTallon/nixed.git ~/.dotfiles
```

The public `nixed` mirror needs no auth and is kept in sync with the
private repo on every update — reconcile personal bits like SSH
allowed_signers from the private repo afterward if needed.

## 8. Swap in the real hardware-configuration.nix

The one in the repo won't match this machine/VM's actual hardware:

```
cp /etc/nixos/hardware-configuration.nix \
  ~/.dotfiles/hosts/<hostname>/hardware-configuration.nix
```

## 9. Rebuild with `boot`, not `switch`, for this first pass

```
sudo nixos-rebuild boot --flake ~/.dotfiles#nixos
```

`switch` tries to activate everything immediately in the current
session, including restarting services — risky right after a fresh
install where the real config's kernel/GPU driver likely differs from
Calamares' minimal defaults. `boot` stages the config and updates the
bootloader entry without touching the live session, so the first real
boot into your actual config happens cleanly on reboot rather than via
a live mid-switch.

`test` alone is **NOT** enough — it activates for the session only and
does **NOT** persist across a reboot or update the bootloader.

## 10. Reboot into the real config

Once confirmed working, `switch` can be used for all subsequent normal
rebuilds as usual.

## 11. Retire the manual hardware-configuration.nix fileSystems entries

Once booted on the real config, the `disko` aspect can be added to the
host's imports in `hosts.nix`, since `disko.devices` now matches
reality. At that point, strip the `fileSystems` (`"/"` and `"/boot"`)
and `swapDevices` stanzas out of `hardware-configuration.nix` for this
host, but leave everything else in hardware-configuration.nix
untouched (kernel modules, microcode, firmware settings, etc.) — disko
is now the sole source of truth for the filesystem entries only, and
leaving the old fileSystems/swapDevices entries in reproduces the
original device-conflict error that prompted this whole runbook.

---

See also: `disko-laptop.nix` / a laptop equivalent of this runbook for
the laptop's equivalent layout/plan.

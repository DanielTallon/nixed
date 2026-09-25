# Fresh Install

Three steps: partition by hand in the graphical installer, install a minimal
system, then one `nix run` pulls this repo and builds the real config.

## 1. Before you start

- **Firmware must be UEFI**, not legacy BIOS (check virt-manager's
  Firmware setting on a VM). The layout below uses a FAT32 ESP, and a
  BIOS install fails at the bootloader step.
- **Desktop:** Windows lives on a separate disk. Confirm with `lsblk`
  which disk is which before touching anything, and leave Windows' disk
  alone.

## Disk space (measured on a VM install, Sept 2026)

- **`/` needs 80 GB minimum; 100 GB recommended.** The first build peaks at
  about 64 GB used. A 47 GB disk ran out partway through. After reboot and
  `sudo nix-collect-garbage -d` it settles around 44 GB.
- **`/boot`:** each distinct kernel set (default + `latest` specialisation,
  with initrds) takes about 500 MB. A 1 GB ESP holds the first install plus
  roughly one kernel update, so you'll need to prune with Boot Gardener. 3 GB
  holds about five, which is what I run.

## 2. Graphical installer (Calamares)

At the partitioning step choose **Manual Partitioning** and create, on the
target disk (GPT):

| Partition | Size      | Filesystem | Mount   | Flags     |
|-----------|-----------|------------|---------|-----------|
| ESP       | 3 GB (1 GB min) | FAT32 | `/boot` | boot, esp |
| root      | remaining | btrfs      | `/`     |           |

See "Disk space" above for why 3 GB.

- Pick the lightest or no desktop environment. The real one comes from
  the rebuild.
- Set the hostname to `nixos` (desktop) or `laptop` so the next step
  finds the right config on its own.
- Create your user with the username you want to keep.

Finish, reboot, and remove the ISO.

## 3. One command

Log in as your normal user (not root) and run:

```
nix --extra-experimental-features 'nix-command flakes' \
  run github:DanielTallon/nixed -- nixos     # or: laptop
```

This clones the repo to `~/.dotfiles`, copies in this machine's
`/etc/nixos/hardware-configuration.nix`, sets `username` in `flake.nix` to
your login name, and runs `sudo nixos-rebuild boot`. Details are in
`modules/bootstrap.nix`.

It deliberately uses `boot`, not `switch`: the real kernel and NVIDIA
driver differ from the installer's defaults, so nothing is activated in the
live session. (`test` isn't enough either. It doesn't survive a reboot.)

## 4. Reboot

Reboot into the new generation. From here on, use `switch` (or
`nh os switch`) for normal rebuilds.

## Afterwards

- Set your git identity and SSH signing key in `home-manager/git.nix`.
  The public copy has placeholders there, and `commit.gpgsign = true`
  will block commits until it's filled in.
- Want to clone to a different path or repo? Set `NIXED_DEST=<path>` or
  `NIXED_REPO=<git url>` before `nix run`.

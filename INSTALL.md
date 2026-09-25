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
your login name, builds the system with a live dependency tree
(nix-output-monitor), and then runs `sudo nixos-rebuild boot` to install
the boot entry. It asks for your sudo password once, at the start. The
build takes a while, so you can walk away. Details are in
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
  `NIXED_REPO=<git url>` before `nix run`. If you change the path, `nh`
  won't find the flake by itself (`programs.nh.flake` points at
  `~/.dotfiles`), so pass the path: `nh os switch <path>`.

## Making it your own

This repo is meant to be a starting point, so feel free to change anything.
Your `~/.dotfiles` is a clone of *this* repo, though, so its `origin` still
points here. You can pull updates from it, but you can't push to it. To
keep your changes under version control:

1. **Fork this repo on GitHub** (or create an empty repo of your own).
2. **Point your clone at your fork**, and keep this repo as `upstream` so
   you can still pull updates from it later:

   ```
   cd ~/.dotfiles
   git remote rename origin upstream
   git remote add origin https://github.com/<you>/<your-repo>.git
   ```

3. **Commit what the installer changed.** The bootstrap leaves your
   `hardware-configuration.nix` and `username` staged but uncommitted. Fill
   in `home-manager/git.nix` first (see above), then:

   ```
   git commit -m "Initial setup for my machine"
   git push -u origin main
   ```

4. **Make the one-command install yours too** (optional). In your fork,
   change the default `repo=` URL in `modules/bootstrap.nix` to your
   repo. Then this installs *your* config on a fresh machine:

   ```
   nix --extra-experimental-features 'nix-command flakes' \
     run github:<you>/<your-repo> -- nixos
   ```

   The host names (`nixos`, `laptop`) and their `hosts/` folders are
   defined in `modules/hosts.nix` and the `case` block in `bootstrap.nix`.
   Rename or add hosts in both places.

To pull in later changes from this repo: `git pull upstream main`. You may
need to resolve conflicts in files you've customized.

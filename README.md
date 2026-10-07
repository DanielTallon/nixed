# nixed

My daily-driver NixOS dotfiles. One setup, two flavors: rolling release for my gaming rig, stable release for my older laptop. Nothing fancy.

A flake-based NixOS + home-manager configuration for my desktop and laptop, managed as modular `.nix` files under `modules/` and `home-manager/`. Shared here as-is in case any of it is useful to someone else — not written as a general-purpose template, so expect to adapt things rather than a turn key experience per se.

This build utilizes: 

- Flakes
- Dendritic pattern
- Limine Bootloader with kernel specialization. use: kernel version to see which version each kern is currently at. I'd recommend you set your boot partition to 2-3GB with everything as is. You can do less, if you don't use the specializations.
- One shared system setup and one shared Home Manager profile, built two ways:
  - `nixos` — rolling release (nixos-unstable). My two monitor desktop, with an RTX 4070 Super GPU and proprietary drivers
  - `nixos-stable` — versioned release (nixos-26.05), with the option to pin any individual package to rolling release via `pkgs-unstable`.
- NVIDIA GPU auto-detection: The install command checks your PCI devices and writes `hosts/<host>/gpu.nix` (`hasNvidia = true/false`) for both installs. So either flavor works with or without an Nvidia card. `nixos` uses Nvidia's newest driver; `nixos-stable` uses the more conservative production branch
- Windows dual-boot auto-detection: This install command also looks for Windows' boot manager on any EFI partition (its own disk or shared with Linux) and, if found, writes a Limine menu entry to `hosts/<host>/dualboot.nix`
- Krohnkite for tiling on KDE Plasma
- Home Manager integrated directly into the NixOS configuration, not run standalone. There's no separate `home-manager` CLI to use here and no home-manager generations to manage on their own — everything under `home-manager/` is applied as part of each `nixos-rebuild`/`nh os switch`, so your user config and system config move together as one generation
- A kernel.nix file to switch between different kernel options. Xddxdd or Chaotic (both from CachyOS), lts if you want long term support. Zen (from Garuda) and Xanmod (very good low latency support). To check the version of each, run: "kernel version" and it will show a current list.
- Specialization, so that you can always load into the latest linux kernel, or whatever you set the default to be, on Limine
- A bootloader limit of 10 generations and a system limit of 35 generations total, automatically cleaned every day.
- A new TUI tool I developed, called Boot Gardener, that allows you to manage your generations easier, and even free up space from /boot.
- `iphone-music-sync`: a one-command way to mirror your music folder onto an iPhone (into VLC for iOS) over USB, plus `idevicebackup2` for full iPhone backups. No iTunes needed. See [iPhone music sync](#iphone-music-sync).
- And other personalizations


## Quick install

Two ways in: after a normal Calamares install, or straight from the NixOS minimal ISO with no graphical installer at all.

### After Calamares

On a fresh NixOS install (partitioned by hand, installed with Calamares), log in as your normal user.

If you would like a quick install of my gaming setup (following the rolling release branch), run:

```
nix run --extra-experimental-features 'nix-command flakes' github:DanielTallon/nixed -- nixos
```

Or if you would like the same setup on the versioned release branch, run:

```
nix run --extra-experimental-features 'nix-command flakes' github:DanielTallon/nixed -- nixos-stable
```

Either one clones this repo to `~/.dotfiles`, drops in your machine's hardware config, sets your username, and rebuilds. Reboot when it finishes. The full walkthrough, including disk sizes and my partition layout, is in [INSTALL.md](INSTALL.md).

### From the minimal ISO (experimental)

Boot the NixOS **minimal** ISO (UEFI), connect with `nmtui` if you're on Wi-Fi, then run:

```
nix run --extra-experimental-features 'nix-command flakes' github:DanielTallon/nixed#install
```

It asks which host you want (rolling release or version release), your username and password, and shows the timezone, language and keyboard it detected so you can change them. Then you pick a disk and **it erases that disk** (3 GB FAT32 `/boot` + btrfs `/`, via disko) and installs a small base system. After it shuts down, and you turn your computer back on (without the ISO media anymore), the install continues to runs by itself. One more reboot lands you in the finished setup. You can find the details in [INSTALL.md](INSTALL.md#quick-install-no-calamares).

## Before you use this

The Calamares won't build or apply as-is on your machine. You'll need to:

1. **Set your own username** — in `flake.nix`, change `username = "youruser";` to your actual username. Everything else in the flake reads from this single value.

2. **Generate your own hardware config** — the files at `hosts/desktop/hardware-configuration.nix` and `hosts/nixos-stable/hardware-configuration.nix` are placeholders. Run:
   ```
   sudo nixos-generate-config
   ```
   and copy the generated `hardware-configuration.nix` into the matching `hosts/<yourhost>/` folder.
   
3. **Set your own git identity** — in `home-manager/git.nix`, replace the placeholder name/email, and swap in your own SSH signing key + `allowed_signers` entry (see git's SSH signing docs if you're not familiar).

4. **Review before applying** — this is a personal config, not a hardened template. Skim through `modules/` and `home-manager/` first so you know what you're opting into (packages, services, etc.) before running `nixos-rebuild switch`.

5. **Don't expect a standalone `home-manager` command to work** — Home Manager here is wired in as a NixOS module, not run as its own service. Use `nixos-rebuild switch` (or `nh os switch`) to apply changes under `home-manager/`, not `home-manager switch`, and don't go looking for home-manager generations — there aren't any separate from the system's own.


## iPhone music sync

I have an iphone, but sadly Apple's Music app can only be filled by iTunes/Finder. So instead this syncs into **VLC for iOS**, over USB - because I am old-school. It's built into both hosts (`modules/iphone-music.nix` + `scripts/iphone-music-sync.sh`), so once you've rebuilt, the `iphone-music-sync` command is just there.

### One-time setup

1. Install **VLC media player** (by VideoLAN, free) from the App Store on your iPhone, and open it once so it creates its Documents folder.
2. Plug the phone in with a cable, unlock it, and tap **Trust** when it asks.
3. Make sure your music lives in your XDG music folder (usually `~/Music`). If it's somewhere else, you can just pass the path each time (see below).

That's it. `usbmuxd`, `ifuse`, `rsync` and `libimobiledevice` all come with the module.

### Usage

```
iphone-music-sync -n                  # dry run: shows what would be copied/deleted, changes nothing
iphone-music-sync                     # sync your music folder to the phone
iphone-music-sync ~/Somewhere/Else    # sync a different folder
```

Keep the phone unlocked while it runs. Afterwards, open VLC on the phone and check the **Audio** tab. If edited tags don't show up right away, fully close VLC and reopen it.

### How it behaves

- **Your computer is the source of truth.** The phone's copy is a mirror: new songs get copied, songs you delete locally get deleted from the phone, and songs you delete *on the phone* come back on the next sync. To remove a song for good, delete it from your computer.
- **Tag edits sync too.** Retagging a song (in Tauon, Picard, etc.) updates its modification time, and the sync compares timestamps, so the new tags get pushed on the next run.
- **It only touches one folder.** Everything goes into a `Music` folder inside VLC's Documents. Anything else you put in VLC (videos, etc.) is left alone.
- **The first sync is slow; after that it's fast.** Only new, changed, or removed files transfer on later runs.
- **Safety checks.** It refuses to run if the phone isn't connected, if VLC isn't installed, if your music folder is empty (e.g. it's on a drive that isn't mounted, which would otherwise wipe the phone), or if the folder resolves to your whole home directory.

Run `iphone-music-sync -n` first the very first time, and after any big cleanup, to see exactly what it will do.

**Already copied music into VLC by hand?** Move it into a `Music` subfolder inside VLC's Documents first, or the first sync will just copy it all again alongside the old copies.

### Options

Two environment variables, if you need them:

- `IPHONE_MUSIC_APP`: the app to sync into (default `org.videolan.vlc-ios`). Run `ifuse --list-apps` with the phone connected to find other apps' IDs.
- `IPHONE_MUSIC_SUBDIR`: the folder inside the app (default `Music`).

Don't want any of this? Remove `iphoneMusic` from the imports in `modules/hosts.nix`.

### Backing up the iPhone

The module also installs `libimobiledevice`, which includes `idevicebackup2`. That makes the same full backup iTunes/Finder would:

```
mkdir -p ~/iphone-backup
idevicebackup2 -i encryption on ~/iphone-backup   # optional: prompts for a password
idevicebackup2 backup --full ~/iphone-backup
```

Encrypted backups also include saved passwords, Health data and Wi-Fi settings. **Don't lose that password**, because the backup can't be restored without it. Restore with `idevicebackup2 restore ~/iphone-backup`.

A first full backup can take an hour or more. Before you start it, set the phone's **Auto-Lock to Never** (Settings → Display & Brightness), and plug into a port on the motherboard rather than a hub or front-panel port. If it stalls (watch `du -sm ~/iphone-backup` and the number stops climbing), unplug the phone to stop it, restart `usbmuxd` (`sudo systemctl restart usbmuxd`), and run it again.

## Structure

- `flake.nix` / `flake.lock` — flake inputs and outputs
- `hosts/` — per-machine hardware configs (desktop, nixos-stable)
- `modules/` — NixOS system modules (bootloader, kernel, nvidia, users, etc.)
- `home-manager/` — user-level (home-manager) configs
- `scripts/` — misc helper scripts (including `iphone-music-sync.sh`)

## License

Feel free to use, adapt, or borrow from anything here.

# nixed

My daily-driver NixOS dotfiles. One setup, two flavors: rolling release for my gaming rig, stable release for my older laptop. Nothing fancy.

A flake-based NixOS + Home Manager config in the dendritic pattern (flake-parts + import-tree: every `.nix` file under `modules/` and `home-manager/` is picked up automatically). Shared as-is in case any of it is useful. It's not a general-purpose template, so expect to adapt things rather than a turnkey experience.

What's in it:

- **Two hosts, one config.** Both share the same system modules and Home Manager profile:
  - `nixos`: nixos-unstable. My two-monitor desktop: RTX 4070 Super on NVIDIA's newest driver, Zen kernel.
  - `nixos-stable`: nixos-26.05, LTS kernel, NVIDIA's production driver if there's a card. Any single package can still come from unstable via `pkgs-unstable`.
- **Hardware detection at install.** The install command checks your PCI devices and writes `hosts/<host>/gpu.nix`, so either host works with or without an NVIDIA card (without one it sets up Intel graphics). It also looks for Windows' boot manager on any EFI partition and adds it to the Limine menu via `hosts/<host>/dualboot.nix`.
- **Limine with switchable kernels.** Set `kernelProvider` in `modules/kernel.nix`: `zen` (default), `xanmod`, `chaotic` (CachyOS), `latest` or `lts`. Unless the default is already LTS, Limine also gets an LTS entry as a fallback, since the others all track the same upstream release and tend to break together. Run `kernel version` to see what each is currently at.
- **Generation cleanup.** Limine shows the newest 10 generations; `nh` keeps 35 and cleans daily. Boot Gardener, a TUI I wrote, helps manage generations, pin old ones to the boot menu and free up space on `/boot`. With everything as is, I'd make `/boot` 2–3 GB.
- **Home Manager as a NixOS module**, so user and system config rebuild together as one generation (see [Before you use this](#before-you-use-this)).
- **KDE Plasma 6** via plasma-manager, with Krohnkite tiling and desktop colors generated from the wallpaper (matugen + my WallpaperPicker).
- **Gaming:** Steam with Proton-GE, Gamescope, GameMode, MangoHud, Heroic, and per-game Proton DPI overrides.
- **VMs:** virt-manager and VM Curator, with Secure Boot firmware and TPM for Windows 11 guests, plus single-GPU passthrough on the desktop.
- **Privacy defaults:** DNS-over-TLS to Cloudflare/Google (so the network's DNS is never asked), locked-down Brave policies, and LibreWolf with DRM on for streaming.
- **Tailscale and RustDesk** for remote support on family machines.
- **`iphone-music-sync`:** one command to mirror your music folder into VLC for iOS over USB, plus `idevicebackup2` for full iPhone backups. No iTunes needed. See [iPhone music sync](#iphone-music-sync).
- And other personalizations (fish, Konsole, Tauon, Discord via Nixcord, Flatpak with Bazaar, nix-index/comma, zram).


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

It asks which host you want (rolling release or version release), your username and password, and shows the timezone, language and keyboard it detected so you can change them. Then you pick a disk and **it erases that disk** (3 GB FAT32 `/boot` + btrfs `/`, via disko) and installs a small base system. After it shuts down, and you turn your computer back on (without the ISO media anymore), the install continues to runs by itself. One more reboot lands you in the finished setup. The ISO's own disk isn't offered, and a disk with Windows or NTFS on it is refused. You can also build an ISO with the installer already on it: `nix build .#installer-iso`. You can find the details in [INSTALL.md](INSTALL.md#quick-install-no-calamares).

## Before you use this

If you're not using the install commands above, this won't build or apply as-is on your machine. You'll need to (the install commands do 1 and 2 for you):

1. **Set your own username** — in `flake.nix`, change `username = "youruser";` to your actual username. Everything else in the flake reads from this single value.

2. **Generate your own hardware config** — the files at `hosts/desktop/hardware-configuration.nix` and `hosts/nixos-stable/hardware-configuration.nix` are placeholders. Run:
   ```
   sudo nixos-generate-config
   ```
   and copy the generated `hardware-configuration.nix` into the matching `hosts/<yourhost>/` folder.
   
3. **Set your own git identity** — in `home-manager/git.nix`, replace the placeholder name/email, and swap in your own SSH signing key + `allowed_signers` entry (see git's SSH signing docs if you're not familiar).

4. **Review before applying** — this is a personal config, not a hardened template. Skim through `modules/` and `home-manager/` first so you know what you're opting into (packages, services, etc.) before running `nixos-rebuild switch`.

5. **Don't expect a standalone `home-manager` command to work** — Home Manager here is wired in as a NixOS module, not run standalone. Everything under `home-manager/` is applied by `nh os switch` (or `nixos-rebuild switch`), not `home-manager switch`, and don't go looking for home-manager generations — there aren't any separate from the system's own.


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
- `hosts/` — per-machine files (desktop, nixos-stable): hardware config, plus `gpu.nix`, `dualboot.nix` and `locale.nix`, written by the install commands
- `modules/` — NixOS system modules (bootloader, kernel, nvidia, users, etc.)
- `home-manager/` — user-level (home-manager) configs
- `installer/` — the minimal-ISO installer (disk layout, base system, first-boot stage)
- `scripts/` — misc helper scripts (including `iphone-music-sync.sh`)
- `limine-pins.json` — old generations Boot Gardener has pinned to the boot menu

## License

Feel free to use, adapt, or borrow from anything here.

# nixed

My daily-driver NixOS dotfiles. One setup, two flavors: rolling release for my gaming rig, stable release for my older laptop. Nothing fancy.

A flake-based NixOS + Home Manager config in the dendritic pattern (flake-parts + import-tree: every `.nix` file under `modules/` is picked up automatically, and each feature keeps its NixOS and Home Manager halves in the same file). Shared as-is in case any of it is useful. It's not a general-purpose template, so expect to adapt things rather than a turnkey experience.

What's in it:

- **Two hosts, one config.** Both share the same system modules and Home Manager profile:
  - `nixos`: nixos-unstable. My two-monitor desktop: RTX 4070 Super on NVIDIA's newest driver, XanMod kernel.
  - `nixos-stable`: nixos-26.05, NVIDIA's production driver if there's a card. Any single package can still come from unstable via `pkgs-unstable`.
- **Hardware detection at install.** The install command checks your PCI devices and writes `hosts/<host>/gpu.nix`, so either host works with or without an NVIDIA card (without one it sets up Intel graphics). It also looks for Windows' boot manager on any EFI partition and adds it to the Limine menu via `hosts/<host>/dualboot.nix`.
- **Limine with switchable kernels.** Set `kernelProvider` in `modules/system/kernel.nix`: `xanmod` (default), `zen`, `chaotic` (CachyOS), `latest` or `lts`. Unless the default is already LTS, Limine also gets an LTS entry as a fallback, since the others all track the same upstream release and tend to break together. Run `kernel version` to see what each is currently at.
- **Generation cleanup.** Limine shows the newest 7 generations; `nh` keeps 35 and cleans daily. Boot Gardener, a TUI I wrote, helps manage generations, pin old ones to the boot menu and free up space on `/boot`. With everything as is, I'd make `/boot` 2–3 GB.
- **Home Manager as a NixOS module**, so user and system config rebuild together as one generation (see [Before you use this](#before-you-use-this)).
- **Niri + Noctalia** as the default session on both hosts: scrollable tiling, the Noctalia shell for the bar, dock and control center, and `nirimod` to edit the Niri config from a GUI. **KDE Plasma 6** stays a choice at the login screen, set up through plasma-manager with Krohnkite tiling. KDE apps look the same in both.
- **Wallpaper picker:** [my packaged kwepaperpicker](https://github.com/DanielTallon/nix-packages#wallpaperpicker), on Super+Space in both sessions. It draws the wallpaper itself in Niri and hands it to Plasma in Plasma, with transitions either way, and every wallpaper it sets recolors the desktop through matugen. It's set up through the Home Manager module in that repo (`modules/desktop/wallpaper-picker.nix`).
- **Gaming:** Steam with Proton-GE and [Proton Wineland](https://github.com/DanielTallon/nix-packages#proton-wineland), Gamescope, GameMode, MangoHud, Heroic, per-game Proton DPI overrides, and Lossless Scaling frame generation (`lsfg-vk`, with its GUI). The kernel runs the `scx_lavd` scheduler CachyOS uses for gaming, plus SteamOS's network and scheduler tweaks. Steam Input works under Niri too.
- **VMs:** virt-manager and VM Curator, with Secure Boot firmware and TPM for Windows 11 guests, plus single-GPU passthrough on the desktop.
- **Privacy defaults:** DNS-over-TLS to Cloudflare/Google (so the network's DNS is never asked), Brave Origin (Brave without Rewards, Wallet, VPN, AI or telemetry, packaged in my nix-packages) with the leftover extras switched off by policy, and LibreWolf with DRM on for streaming.
- **Drive health and firmware:** `smartd` warns when a drive starts failing, and `fwupd` updates firmware when you ask (`fwupdmgr refresh`, then `fwupdmgr update`).
- **Tailscale and RustDesk** for remote support.
- **Binary caches**, including [my own Cachix](https://github.com/DanielTallon/nix-packages#binary-cache), so my packages download instead of compiling. `nix-fast-build` builds both hosts in parallel to check them, and `nix-tree` shows what's in a build and why.
- **`iphone-music-sync`:** one command to mirror your music folder into VLC for iOS over USB, plus `idevicebackup2` for full iPhone backups. No iTunes needed. See [iPhone music sync](#iphone-music-sync).
- And other personalizations (fish, with `trim` and `vol` for cutting songs and changing their volume; Ghostty and Konsole; Tauon, with a fix for its tag editor; Discord via Nixcord; Flatpak with Bazaar; nix-index/comma; zram).


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

Either one clones this repo to `~/.dotfiles`, drops in your machine's hardware config, sets your username, and rebuilds. Reboot when it finishes, then run `nh os switch` once: the install leaves out the few apps no binary cache has (Flow, plus RustDesk and LocalSend on the rolling release), so it's nearly all downloads, and that first switch compiles and adds them. To build everything during the install instead, put `NIXED_FULL=1` in front of the command. The full walkthrough, including disk sizes and my partition layout, is in [INSTALL.md](INSTALL.md).

### From the minimal ISO (experimental)

Boot the NixOS **minimal** ISO (UEFI), connect with `nmtui` if you're on Wi-Fi, then run:

```
nix run --extra-experimental-features 'nix-command flakes' github:DanielTallon/nixed#install
```

It asks which host you want (rolling release or version release), your username and password, and shows the timezone, language and keyboard it detected so you can change them. Then you pick a disk and **it erases that disk** (3 GB FAT32 `/boot` + btrfs `/`, via disko) and installs a small base system. After it shuts down, and you turn your computer back on (without the ISO media anymore), the install continues by itself. One more reboot lands you in the finished setup; as above, run `nh os switch` once to add the apps the install left out. The ISO's own disk isn't offered, and a disk with Windows or NTFS on it is refused. You can also build an ISO with the installer already on it: `nix build .#installer-iso`. You can find the details in [INSTALL.md](INSTALL.md#quick-install-no-calamares).

## Updating

Already installed? To get my latest changes and settings, run:

```
nix run github:DanielTallon/nixed#update
```

Then rebuild with `nh os switch`. The update pulls this repo into `~/.dotfiles` but keeps your machine's own files: your username and your `hosts/<host>/` files (hardware config, GPU, dual-boot, locale). The install tells git to leave those alone, so a pull never overwrites them. Noctalia rewrites its settings file while it runs, so the update pauses Noctalia for a moment and replaces any changes you made in its settings window with mine. If you installed before the username moved to `username.nix` (November 18, 2026), the first update moves it there for you.

## Before you use this

If you're not using the install commands above, this won't build or apply as-is on your machine. You'll need to (the install commands do 1 and 2 for you):

1. **Set your own username** — in `username.nix`, change `"youruser"` to your actual username. Everything else in the flake reads from this single value.

2. **Generate your own hardware config** — the files at `hosts/desktop/hardware-configuration.nix` and `hosts/nixos-stable/hardware-configuration.nix` are placeholders. Run:
   ```
   sudo nixos-generate-config
   ```
   and copy the generated `hardware-configuration.nix` into the matching `hosts/<yourhost>/` folder.
   
3. **Set your own git identity** — in `modules/dev/git.nix`, replace the placeholder name/email, and swap in your own SSH signing key + `allowed_signers` entry (see git's SSH signing docs if you're not familiar).

4. **Review before applying** — this is a personal config, not a hardened template. Skim through `modules/` first so you know what you're opting into (packages, services, etc.) before running `nixos-rebuild switch`.

5. **Don't expect a standalone `home-manager` command to work** — Home Manager here is wired in as a NixOS module, not run standalone. Every `flake.modules.homeManager.*` half is applied by `nh os switch` (or `nixos-rebuild switch`), not `home-manager switch`, and don't go looking for home-manager generations — there aren't any separate from the system's own.


## iPhone music sync

I have an iphone, but sadly Apple's Music app can only be filled by iTunes/Finder. So instead this syncs into **VLC for iOS**, over USB - because I am old-school. It's built into both hosts (`modules/apps/iphone.nix` + `scripts/iphone-music-sync.sh`), so once you've rebuilt, the `iphone-music-sync` command is just there.

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
iphone-music-sync -i                  # show the plugged-in phone's name and UDID
```

Keep the phone unlocked while it runs. Afterwards, open VLC on the phone and check the **Audio** tab. If edited tags don't show up right away, fully close VLC and reopen it.

### More than one phone

To sync a different folder to each phone (say, a friend's iPhone gets her own music and not yours), list the phones in `~/.config/iphone-music-sync/phones`, one per line:

```
# UDID                      FOLDER          APP (optional)
00008110-001A2B3C4D5E6F70   ~/Music
00008030-00456789ABCDEF01   ~/FriendMusic   org.videolan.vlc-ios
```

Plug each phone in and run `iphone-music-sync -i` to get its UDID. The app column is optional (VLC if left out), and `ifuse -u UDID --list-apps` shows the app IDs that phone can take. Folder paths can't contain spaces.

Once the file exists, a plain `iphone-music-sync` looks up whichever phone is plugged in and syncs its folder, and **refuses any phone that isn't listed**, so a new phone never gets your library by accident. Plug in one phone at a time; it refuses if it sees more than one. A folder given on the command line still overrides the file. Keep each phone's folder outside the others (e.g. not `~/Music/Friend` inside your `~/Music`), or it will get copied to both phones.

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

- `IPHONE_MUSIC_APP`: the app to sync into (default: the phone's app from the phones file, or `org.videolan.vlc-ios`). Run `ifuse --list-apps` with the phone connected to find other apps' IDs.
- `IPHONE_MUSIC_SUBDIR`: the folder inside the app (default `Music`).

Don't want any of this? Remove the `"iphone"` line from `features` in `modules/hosts.nix`.

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
- `modules/` — one file per feature, grouped into `system/`, `desktop/`, `shell/`, `dev/`, `apps/` and `gaming/`. A feature file defines `flake.modules.nixos.<name>`, `flake.modules.homeManager.<name>`, or both, so a feature's system and user config live together (Kate and the nixd it uses, Fish and the login shell, Steam and its per-game Proton DPI)
- `modules/hosts.nix` — the two hosts and the single `features` list both of them get, plus a `<host>-firstboot` variant of each that the installer builds first
- `modules/checks.nix` — both hosts as flake checks, for `nix-fast-build`
- `modules/desktop/niri/` and `modules/desktop/noctalia/` — Niri's `config.kdl` and Noctalia's `settings.toml`, linked into place rather than copied, so changes made in nirimod or Noctalia's settings window land straight in the repo
- `installer/` — the minimal-ISO installer (disk layout, base system, first-boot stage)
- `scripts/` — misc helper scripts (including `iphone-music-sync.sh`)
- `limine-pins.json` — old generations Boot Gardener has pinned to the boot menu

## License

[MIT](LICENSE). Feel free to use, adapt, or borrow from anything here.

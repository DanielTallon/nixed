# nixed

My daily-driver NixOS dotfiles. One setup, two flavors: rolling release for my gaming rig, stable release for my older laptop. Nothing fancy.

A flake-based NixOS + home-manager configuration for my desktop and laptop, managed as modular `.nix` files under `modules/` and `home-manager/`. Shared here as-is in case any of it is useful to someone else — not written as a general-purpose template, so expect to adapt things rather than a turn key experience per se.

This build utilizes: 

- Flakes
- Dendritic pattern
- Limine Bootloader with kernel specialization. use: kernel version to see which version each kern is currently at. I'd recommend you set your boot partition to 2-3GB with everything as is. You can do less, if you don't use the specializations.
- One shared system setup and one shared Home Manager profile, built two ways:
  - `nixos` — rolling release (nixos-unstable). My two monitor desktop, with an RTX 4070 Super GPU and proprietary drivers
  - `nixos-stable` — versioned release (nixos-26.05), with any individual package switchable to unstable via `pkgs-unstable`. Runs on my older laptop, which has no Nvidia GPU
- NVIDIA auto-detection: the install command checks your PCI devices and writes `hosts/<host>/gpu.nix` (`hasNvidia = true/false`), so either flavor works with or without an Nvidia card. `nixos` uses Nvidia's newest driver; `nixos-stable` uses the more conservative production branch
- Krohnkite for tiling on KDE Plasma
- Home Manager integrated directly into the NixOS configuration, not run standalone. There's no separate `home-manager` CLI to use here and no home-manager generations to manage on their own — everything under `home-manager/` is applied as part of each `nixos-rebuild`/`nh os switch`, so your user config and system config move together as one generation
- A kernel.nix file to switch between different kernel options. Xddxdd or Chaotic (both from CachyOS), lts if you want long term support. Zen (from Garuda) and Xanmod (very good low latency support). To check the version of each, run: "kernel version" and it will show a current list.
- Specialization, so that you can always load into the latest linux kernel, or whatever you set the default to be, on Limine
- A bootloader limit of 10 generations and a system limit of 35 generations total, automatically cleaned every day.
- A new TUI tool I developed, called Boot Gardener, that allows you to manage your generations easier, and even free up space from /boot.
- And other personalizations


## Quick install

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

## Before you use this

This won't build or apply as-is on your machine. You'll need to:

1. **Set your own username** — in `flake.nix`, change `username = "youruser";` to your actual username. Everything else in the flake reads from this single value.

2. **Generate your own hardware config** — the files at `hosts/desktop/hardware-configuration.nix` and `hosts/nixos-stable/hardware-configuration.nix` are placeholders. Run:
   ```
   sudo nixos-generate-config
   ```
   and copy the generated `hardware-configuration.nix` into the matching `hosts/<yourhost>/` folder.
3. **Set your own git identity** — in `home-manager/git.nix`, replace the placeholder name/email, and swap in your own SSH signing key + `allowed_signers` entry (see git's SSH signing docs if you're not familiar).
4. **Review before applying** — this is a personal config, not a hardened template. Skim through `modules/` and `home-manager/` first so you know what you're opting into (packages, services, etc.) before running `nixos-rebuild switch`.
5. **Don't expect a standalone `home-manager` command to work** — Home Manager here is wired in as a NixOS module, not run as its own service. Use `nixos-rebuild switch` (or `nh os switch`) to apply changes under `home-manager/`, not `home-manager switch`, and don't go looking for home-manager generations — there aren't any separate from the system's own.


## Structure

- `flake.nix` / `flake.lock` — flake inputs and outputs
- `hosts/` — per-machine hardware configs (desktop, nixos-stable)
- `modules/` — NixOS system modules (bootloader, kernel, nvidia, users, etc.)
- `home-manager/` — user-level (home-manager) configs
- `scripts/` — misc helper scripts

## License

Feel free to use, adapt, or borrow from anything here.


# nixed

My daily-driver NixOS dotfiles. Gaming rig, and simple laptop. Nothing fancy.

A flake-based NixOS + home-manager configuration for my desktop and laptop, managed as modular `.nix` files under `modules/` and `home-manager/`. Shared here as-is in case any of it is useful to someone else — not written as a general-purpose template, so expect to adapt things rather than a turn key experience per se.

This build utilizes: 

- Flakes
- Dendritic pattern
- Limine Bootloader with kernel specialization. use: kernel version to see which version each kern is currently at. I'd recommend you set your boot partition to 2-3GB with everything as is. You can do less, if you don't use the specializations.
- A two monitor desktop setup, using an RTX 4070 Super GPU, and proprietary drivers. Set to rolling release
- An older laptop setup with no Nvidia GPU. Set to fixed release
- A boolean "hasNvidia" set to true on the desktop and false on the laptop 
- Krohnkite for tiling on KDE Plasma
- A kernel.nix file to switch between different kernel options. Xddxdd or Chaotic (both from CachyOS), lts if you want long term support. Zen (from Garuda) and Xanmod (very good low latency support). To check the version of each, run: "kernel version" and it will show a current list.
- Specialization, so that you can always load into the latest linux kernel, or whatever you set the default to be, on Limine
- A bootloader limit of 10 generations and a system limit of 35 generations total, automatically cleaned every day.
- The ability to pin an older generation on Limine, as long as it is pinned within 35 generations, then you always have it.
- And other personalizations


## Before you use this

This won't build or apply as-is on your machine. You'll need to:

1. **Set your own username** — in `flake.nix`, change `username = "youruser";` to your actual username. Everything else in the flake reads from this single value.

2. **Generate your own hardware config** — the files at `hosts/desktop/hardware-configuration.nix` and `hosts/laptop/hardware-configuration.nix` are placeholders. Run:
   ```
   sudo nixos-generate-config
   ```
   and copy the generated `hardware-configuration.nix` into the matching `hosts/<yourhost>/` folder.
3. **Set your own git identity** — in `home-manager/git.nix`, replace the placeholder name/email, and swap in your own SSH signing key + `allowed_signers` entry (see git's SSH signing docs if you're not familiar).
4. **Review before applying** — this is a personal config, not a hardened template. Skim through `modules/` and `home-manager/` first so you know what you're opting into (packages, services, etc.) before running `nixos-rebuild switch`.

## Structure

- `flake.nix` / `flake.lock` — flake inputs and outputs
- `hosts/` — per-machine configs (desktop, laptop)
- `modules/` — NixOS system modules (bootloader, kernel, graphics, users, etc.)
- `home-manager/` — user-level (home-manager) configs
- `scripts/` — misc helper scripts

## License

Feel free to use, adapt, or borrow from anything here.


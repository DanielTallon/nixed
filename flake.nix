#✅ /.dotfiles/flake.nix ❌
{
  description = "NixOS Flake with Home Manager, Switchable Kernels";

  inputs = {
    # --- Community flakes ---
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    areofyl-fetch.url = "github:areofyl/fetch";

    # --- Dendritic pattern machinery ---
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    systems.url = "github:nix-systems/default-linux";

    # --- Disko Installer---
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # --- Home Manager (follows unstable) ---
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Kernel & extras ---
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    # --- Personal packages (LGL-Papercutter & Kenku-FM) ---
    nix-packages.url = "github:DanielTallon/nix-packages";


    # --- Multiverse (Pull Any Published Package) ---
    multiverse.url = "github:fzakaria/nixpkgs-multiverse";

    # --- Nixcord
    nixcord.url = "github:4evy/nixcord";

    # --- NClean ---
    nclean.url = "github:p0nczek/nclean";

    # --- Nix Index ---
    nix-index-database.url = "github:nix-community/nix-index-database";
      nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    #--- Proton-CachyOS ---
    nix-proton-cachyos = {
      url = "github:kimjongbing/nix-proton-cachyos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Plasma Manager ---
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # --- Stable (pinned packages, e.g. kenku-fm) ---
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    # --- Unstable (primary) ---
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  # The only file in this repo that isn't a flake-parts module.
  # Every *.nix file under ./modules and ./home-manager is auto-discovered
  # by import-tree — no manual imports list to keep in sync.
  outputs = inputs:
    let
    username = "youruser";
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.flake-parts.flakeModules.modules
        inputs.home-manager.flakeModules.home-manager
        (inputs.import-tree ./modules)
        (inputs.import-tree ./home-manager)
      ];
      _module.args.username = username;
    };
}
      # NOTE:


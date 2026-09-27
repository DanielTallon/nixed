# /.dotfiles/modules/hosts.nix
#NOTE:The only file that knows about concrete machines ("nixos", "nixos-stable").
# Both hosts get the same system setup (`common`) and the same home-manager
# profile (`homeManager.desktop`). What differs:
#   - nixos:        nixos-unstable base, NVIDIA, plus this desktop's own
#                   hardware bits (Windows entry, NTFS drive, CPU governor).
#   - nixos-stable: nixos-26.05 base with `pkgs-unstable` as a per-package
#                   opt-in, `hasNvidia = false`, LTS kernel.
# Adding an aspect to both hosts = one more line in `common` below.
# Adding a new host = one more `mkHost` call plus a small host module.
{ inputs, config, username, ... }:
let
  system = "x86_64-linux";

  # Desktop's base `pkgs` is nixos-unstable (see flake.nix); nixpkgs-stable
  # is the pinned secondary (kenku-fm, strawberry, obs-studio, bottles, vlc,
  # vulkan-loader/validation-layers). On nixos-stable it's the same set as
  # the base `pkgs`, so `pkgs-stable.foo` still resolves there.
  pkgs-stable = import inputs.nixpkgs-stable {
    inherit system;
    config.allowUnfree = true;
  };

  # nixos-stable's base `pkgs` is nixpkgs-stable instead; this is the
  # nixos-unstable channel, exposed there as an opt-in secondary
  # (`pkgs-unstable.somePackage` in packages.nix). Not passed to the
  # desktop, where packages.nix falls back to `pkgs` (already unstable).
  pkgs-unstable = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  # Everything both hosts share outside their own host module: the
  # home-manager wiring and the specialArgs. `nixpkgs` picks the base channel.
  mkHost = { nixpkgs, hostModule, extraArgs ? { } }:
    let args = { inherit inputs pkgs-stable username; } // extraArgs;
    in nixpkgs.lib.nixosSystem {
      specialArgs = args;
      modules = [
        { nixpkgs.hostPlatform = system; }
        inputs.home-manager.nixosModules.home-manager
        hostModule
        {
          home-manager = {
            backupFileExtension = "backup";
            useGlobalPkgs = true;
            useUserPackages = true;
            sharedModules = [ inputs.plasma-manager.homeModules.plasma-manager ];
            extraSpecialArgs = args;
            users.${username}.imports = [ config.flake.modules.homeManager.desktop ];
          };
        }
      ];
    };
in
{
  #---Shared system setup: every aspect both hosts get---
  flake.modules.nixos.common = {
    imports = [
      config.flake.modules.nixos.bootloader
      config.flake.modules.nixos.cavalier
      config.flake.modules.nixos.chaotic
      config.flake.modules.nixos.core
      config.flake.modules.nixos.desktopEnvironment
      config.flake.modules.nixos.graphics
      config.flake.modules.nixos.flatpak
      config.flake.modules.nixos.kernel
      config.flake.modules.nixos.multiverse
      config.flake.modules.nixos.nixCaches
      config.flake.modules.nixos.packages
      config.flake.modules.nixos.zram

      {
        custom.cavalier.enable = true;

        # Boot Gardener pins. Shared file: a pin points at store paths that
        # only exist on the machine that made it, so clear pins before
        # building the other host (see Boot Gardener's --output flag for
        # per-host files if that gets annoying).
        custom.limineManualPins = builtins.fromJSON (builtins.readFile ../limine-pins.json);
      }
    ];
  };

  #---Desktop: rolling release, NVIDIA---
  flake.modules.nixos.desktop = {
    imports = [
      config.flake.modules.nixos.common
      ../hosts/desktop/hardware-configuration.nix

      {
        networking.hostName = "nixos";
        system.stateVersion = "25.11";
        powerManagement.cpuFreqGovernor = "performance";

        # hasNvidia defaults to true (see modules/graphics.nix) — no override needed here.

        # Windows dual-boot entry (desktop only — this disk layout is
        # specific to this machine's EFI partition).
        boot.loader.limine.extraEntries = ''
          /Windows
            protocol: efi
            path: uuid(688b7e62-0a88-4d97-88f4-03d66ba379ab):/EFI/Microsoft/Boot/bootmgfw.efi
        '';

        # Secondary NTFS drive (desktop only).
        fileSystems."/smssd" = {
          device = "/dev/disk/by-uuid/E64C9E294C9DF511";
          fsType = "ntfs";
          options = [ "defaults" "nofail" ];
        };
      }
    ];
  };

  #---nixos-stable: versioned release, no NVIDIA (the old "laptop" host)---
  flake.modules.nixos.nixosStable = {
    imports = [
      config.flake.modules.nixos.common
      ../hosts/nixos-stable/hardware-configuration.nix

      ({ lib, ... }: {
        networking.hostName = "nixos-stable";
        # Assumed fresh install on the 26.05 stable channel — change if this
        # doesn't match what the machine was actually first installed with.
        system.stateVersion = "26.05";

        hasNvidia = false; # Intel UHD only — see modules/graphics.nix

        # Uses the plain LTS kernel (always cached on the standard binary
        # cache) instead of the shared default ("xddxdd" — a custom
        # cachyos-bore-lto build via a niche substituter). That default is
        # fine on desktop where it's already been built/cached, but on a
        # different base pkgs revision (stable vs. unstable) it means
        # compiling a full kernel from source locally.
        #
        # mkDefault (not a plain assignment) so kernel.nix's "latest"
        # specialisation can override it with a plain assignment instead
        # of needing lib.mkForce.
        kernelProvider = lib.mkDefault "lts";
      })
    ];
  };

#---Per-user module list — Configures your home directory and user-session state, not the whole OS.
# Shared by both hosts.
  flake.modules.homeManager.desktop = {
    imports = [
      config.flake.modules.homeManager.aliases
      config.flake.modules.homeManager.discord
      config.flake.modules.homeManager.fastfetch
      config.flake.modules.homeManager.fetch
      config.flake.modules.homeManager.fish
      config.flake.modules.homeManager.git
      config.flake.modules.homeManager.glava
      config.flake.modules.homeManager.home
      config.flake.modules.homeManager.kate
      config.flake.modules.homeManager.konsole
      config.flake.modules.homeManager.krohnkite
      config.flake.modules.homeManager.nix-index
      config.flake.modules.homeManager.plasma
      config.flake.modules.homeManager.protonDpi
      config.flake.modules.homeManager.xdgUserDirs
        {
          custom.protonDpi."2105600" = 192; # Larger loading window for RPG Stories
          #custom.protonDpi."2105600" = 96; # Default setting
          #96	100%
          #120	125%
          #144	150%
          #168	175%
          #192	200%
          #216	225%
          #240	250%
          #288	300%

        }
      ];
    };

  flake.nixosConfigurations.nixos = mkHost {
    nixpkgs = inputs.nixpkgs;
    hostModule = config.flake.modules.nixos.desktop;
  };

  flake.nixosConfigurations.nixos-stable = mkHost {
    nixpkgs = inputs.nixpkgs-stable;
    hostModule = config.flake.modules.nixos.nixosStable;
    extraArgs = { inherit pkgs-unstable; };
  };
}

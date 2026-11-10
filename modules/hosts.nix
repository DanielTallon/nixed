# /.dotfiles/modules/hosts.nix
#NOTE:The only file that knows about concrete machines ("nixos", "nixos-stable").
# Those are the flake's configuration names; both machines' hostname is "nixos".
# Both hosts get the same system setup (`common`) and the same home-manager
# profile (`homeManager.desktop`). What differs:
#   - nixos:        nixos-unstable base, NVIDIA (newest driver), plus this
#                   desktop's own hardware bits (NTFS drive, CPU governor).
#   - nixos-stable: nixos-26.05 base with `pkgs-unstable` as a per-package
#                   opt-in, LTS kernel, NVIDIA production driver if present.
# Whether a machine has an NVIDIA card lives in hosts/<host>/gpu.nix, and its
# Windows boot entry (if any) in hosts/<host>/dualboot.nix. The bootstrap app
# (modules/bootstrap.nix) writes both by detecting the hardware. Timezone,
# language and keyboard overrides live in hosts/<host>/locale.nix (written
# by the nixed installer, modules/installer.nix; { } otherwise).
# Adding an aspect to both hosts = one more line in `common` below.
# Adding a new host = one more `mkHost` call plus a small host module.
{ inputs, config, lib, username, ... }:
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

  # nixos-unstable channel, exposed there as an opt-in secondary
  # (`pkgs-unstable.somePackage` in packages.nix).
  # nixos-unstable as a secondary package set, passed to both hosts. On
  # nixos-stable it's the opt-in (`pkgs-unstable.somePackage` in
  # packages.nix); on the desktop it's the same nixpkgs as the base `pkgs`.
  pkgs-unstable = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  # Everything both hosts share outside their own host module: the
  # home-manager wiring and the specialArgs. `nixpkgs` picks the base channel.
  #
  # Both hosts use the hostname "nixos", so the hostname can't tell nh (or
  # the bootstrap app) which nixosConfigurations entry this machine is.
  # `name` is that entry; it's written to /etc/nixed-host and NH_OS_FLAKE
  # points nh at it, so a plain `nh os switch` builds the right one.
  mkHost = { name, nixpkgs, hostModule, extraArgs ? { } }:
    let args = { inherit inputs pkgs-stable pkgs-unstable username; } // extraArgs;
    in nixpkgs.lib.nixosSystem {
      specialArgs = args;
      modules = [
        { nixpkgs.hostPlatform = system; }
        {
          networking.hostName = "nixos";
          environment.etc."nixed-host".text = name;
          environment.sessionVariables.NH_OS_FLAKE = "/home/${username}/.dotfiles#${name}";

          # Tie each generation to the config that built it, so a rollback
          # can be traced back to its source without GitHub.
          # `nixos-rebuild list-generations` / `nixos-version
          # --configuration-revision` show the commit ("-dirty" if built
          # with uncommitted changes), and /etc/nixos-config-source is a
          # read-only copy of the flake's git-tracked files as built.
          system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or "unknown";
          environment.etc."nixos-config-source".source = inputs.self;
        }
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

  # Every feature both hosts get, one line each. A feature is a file under
  # modules/ that defines flake.modules.nixos.<name>,
  # flake.modules.homeManager.<name>, or both; listing the name here pulls in
  # whichever halves exist (the home-manager half via homeManager.desktop
  # below). Dropping a feature = deleting its line.
  features = [
    # --- System ---
    "audio"
    "bluetooth"
    "bootloader"
    "chaotic"
    "hardware"
    "kernel"
    "locale"
    "multiverse"
    "networking"
    "nix"
    "nvidia"
    "tailscale"
    "user"
    "vm"
    "zram"

    # --- Desktop ---
    "display"
    "flatpak"
    "ghostty"
    "kate"
    "konsole"
    "krohnkite"
    "plasma"
    "wallpaper"
    "wallpaperColors"
    "xdgUserDirs"

    # --- Shell ---
    "aliases"
    "fastfetch"
    "fetch"
    "fish"
    "superfile"

    # --- Dev ---
    "git"

    # --- Apps ---
    "brave"
    "discord"
    "glava"
    "iphone"
    "librewolf"
    "packages"
    "spotify"
    "tauon"
    "vlc"

    # --- Gaming ---
    "gaming"
    "steam"
  ];

  # The `class` half (nixos or homeManager) of every feature that has one.
  # A name with neither half is a typo, so it fails instead of doing nothing.
  featureModules = class:
    let
      inherit (config.flake) modules;
      unknown = lib.filter (name: !(modules.nixos ? ${name} || modules.homeManager ? ${name})) features;
    in
    lib.throwIf (unknown != [ ]) "modules/hosts.nix: no feature named ${lib.concatStringsSep ", " unknown}"
      (map (name: modules.${class}.${name}) (lib.filter (name: modules.${class} ? ${name}) features));
in
{
  #---Shared system setup: every feature's NixOS half, for both hosts---
  flake.modules.nixos.common = {
    imports = featureModules "nixos" ++ [
      {
        # Boot Gardener pins. Shared file: a pin points at store paths that
        # only exist on the machine that made it, so clear pins before
        # building the other host (see Boot Gardener's --output flag for
        # per-host files if that gets annoying).
        custom.limineManualPins = builtins.fromJSON (builtins.readFile ../limine-pins.json);
      }
    ];
  };

  #--- Rolling release, NVIDIA ---
  flake.modules.nixos.desktop = {
    imports = [
#       inputs.determinate.nixosModules.default
      config.flake.modules.nixos.common
      ../hosts/desktop/hardware-configuration.nix
      ../hosts/desktop/gpu.nix # hasNvidia, written by the bootstrap app
      ../hosts/desktop/dualboot.nix # Windows entry, written by the bootstrap app
      ../hosts/desktop/locale.nix # timezone/language/keyboard, from the nixed installer
      config.flake.modules.nixos.niri # Niri + Noctalia as a second login session (modules/desktop/niri.nix)

      {
        system.stateVersion = "25.11";
        programs.gamemode.settings.cpu.pin_cores = "0-15"; # 14700KF P-core threads
        custom.vm.gpuPassthrough.enable = true;

        # Secondary NTFS drive (desktop only).
        fileSystems."/smssd" = {
          device = "/dev/disk/by-uuid/E64C9E294C9DF511";
          fsType = "ntfs";
          options = [ "defaults" "nofail" ];
        };
      }
    ];
  };

  #--- Versioned release, NVIDIA auto-detected ---
  flake.modules.nixos.nixosStable = {
    imports = [
      config.flake.modules.nixos.common
      ../hosts/nixos-stable/hardware-configuration.nix
      ../hosts/nixos-stable/gpu.nix # hasNvidia, written by the bootstrap app
      ../hosts/nixos-stable/dualboot.nix # Windows entry, written by the bootstrap app
      ../hosts/nixos-stable/locale.nix # timezone/language/keyboard, from the nixed installer

      ({ config, lib, ... }: {
        # Assumed fresh install on the 26.05 stable channel — change if this
        # doesn't match what the machine was actually first installed with.
        system.stateVersion = "26.05";

        # Stable machines get NVIDIA's conservative production driver branch
        # instead of the desktop's `latest`. Only takes effect when
        # hasNvidia = true. mkForce because nvidia.nix sets the package
        # with a plain assignment.
        hardware.nvidia.package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.production;

        # Uses the plain LTS kernel (always cached on the standard binary
        # cache) instead of the shared default ("zen"), which tracks the
        # newest upstream release.
        #
        # mkDefault (not a plain assignment) so a kernel.nix specialisation
        # can override it with a plain assignment instead of needing
        # lib.mkForce. With "lts" as the default there's no LTS
        # specialisation here, since it would duplicate the default entry.
        kernelProvider = lib.mkDefault "lts";
      })
    ];
  };

#---Per-user setup: every feature's home-manager half. Configures your home
# directory and user-session state, not the whole OS. Shared by both hosts.
  flake.modules.homeManager.desktop = {
    imports = featureModules "homeManager";
  };

  flake.nixosConfigurations.nixos = mkHost {
    name = "nixos";
    nixpkgs = inputs.nixpkgs;
    hostModule = config.flake.modules.nixos.desktop;
  };

  flake.nixosConfigurations.nixos-stable = mkHost {
    name = "nixos-stable";
    nixpkgs = inputs.nixpkgs-stable;
    hostModule = config.flake.modules.nixos.nixosStable;

  };
}

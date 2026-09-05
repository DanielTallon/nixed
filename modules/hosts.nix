# /.dotfiles/modules/hosts.nix
#NOTE:The only file that knows about concrete machines ("desktop", "laptop").
# Adding a new aspect to a host = one more line in its imports list below.
# Adding a new host = a new block modeled on one of these.
{ inputs, config, username, ... }:
let
  system = "x86_64-linux";

  # Desktop's base `pkgs` is nixos-unstable (see flake.nix); nixpkgs-stable
  # is the pinned secondary (kenku-fm, strawberry, obs-studio, bottles, vlc,
  # vulkan-loader/validation-layers).
  pkgs-stable = import inputs.nixpkgs-stable {
    inherit system;
    config.allowUnfree = true;
  };

  # Laptop's base `pkgs` is nixpkgs-stable instead (see nixosConfigurations.laptop
  # below); this is the same nixos-unstable channel, exposed as an opt-in
  # secondary there for the occasional unstable package.
  pkgs-unstable = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in
{
  flake.modules.nixos.desktop = {
    imports = [
      config.flake.modules.nixos.bootloader
      config.flake.modules.nixos.cavalier
      config.flake.modules.nixos.chaotic
      config.flake.modules.nixos.core
      config.flake.modules.nixos.desktopEnvironment
      config.flake.modules.nixos.flatpak
      config.flake.modules.nixos.graphics
      config.flake.modules.nixos.kenkuFm
      config.flake.modules.nixos.kernel
      config.flake.modules.nixos.multiverse
      config.flake.modules.nixos.nclean
      config.flake.modules.nixos.packages
      config.flake.modules.nixos.zram

      ../hosts/desktop/hardware-configuration.nix

      # Host-specific bits that used to live in hosts/desktop/default.nix
      {
        networking.hostName = "nixos";
        system.stateVersion = "25.11";
        powerManagement.cpuFreqGovernor = "performance";

        # hasNvidia defaults to true (see modules/graphics.nix) — no override needed here.

        custom.cavalier.enable = true;

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

  flake.modules.nixos.laptop = {
    imports = [
      config.flake.modules.nixos.bootloader
      config.flake.modules.nixos.diskoLaptop
      config.flake.modules.nixos.kernel
      config.flake.modules.nixos.zram
      config.flake.modules.nixos.graphics
      config.flake.modules.nixos.desktopEnvironment
      config.flake.modules.nixos.core
      config.flake.modules.nixos.flatpak
      config.flake.modules.nixos.nclean
      config.flake.modules.nixos.packages
      config.flake.modules.nixos.chaotic


      ../hosts/laptop/hardware-configuration.nix

      ({ lib, ... }: {
        networking.hostName = "laptop";
        # Assumed fresh install on the 26.05 stable channel — change if this
        # doesn't match what the laptop was actually first installed with.
        system.stateVersion = "26.05";

        hasNvidia = false; # Intel UHD only — see modules/graphics.nix

        # Uses the plain LTS kernel (always cached on the standard binary
        # cache) instead of the shared default ("xddxdd" — a custom
        # cachyos-bore-lto build via a niche substituter). That default is
        # fine on desktop where it's already been built/cached, but on a
        # fresh host with a different base pkgs revision (stable vs.
        # unstable) it means compiling a full kernel from source locally.
        # Switch back to another provider once desktop's cache catches up
        # to the laptop's stable channel, if you want parity.
        #
        # mkDefault (not a plain assignment) so kernel.nix's "latest"
        # specialisation can override it with a plain assignment instead
        # of needing lib.mkForce.
        kernelProvider = lib.mkDefault "lts";
      })
    ];
  };

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
      config.flake.modules.homeManager.lglPapercutter
      config.flake.modules.homeManager.nix-index
      config.flake.modules.homeManager.plasma
      ];
    };

  flake.nixosConfigurations.nixos = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs pkgs-stable username; };
    modules = [
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      config.flake.modules.nixos.desktop
      {
        home-manager = {
          backupFileExtension = "backup";
          useGlobalPkgs = true;
          useUserPackages = true;
          sharedModules = [ inputs.plasma-manager.homeModules.plasma-manager ];
          extraSpecialArgs = { inherit inputs pkgs-stable username; };
          users.${username}.imports = [ config.flake.modules.homeManager.desktop
          ];
        };
      }
    ];
  };

  flake.nixosConfigurations.laptop = inputs.nixpkgs-stable.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs pkgs-stable pkgs-unstable username; };
    modules = [
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      config.flake.modules.nixos.laptop
      {
        home-manager = {
          backupFileExtension = "backup";
          useGlobalPkgs = true;
          useUserPackages = true;
          sharedModules = [ inputs.plasma-manager.homeModules.plasma-manager ];
          extraSpecialArgs = { inherit inputs pkgs-stable pkgs-unstable username; };
          # Reuses the same home-manager profile as desktop — nothing in it
          # is desktop-specific (fetch/fish/git/plasma/oh-my-posh/ghostty).
          users.${username}.imports = [ config.flake.modules.homeManager.desktop ];
        };
      }
    ];
  };
}

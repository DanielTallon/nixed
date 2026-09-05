# /.dotfiles/modules/kernel.nix
# Switchable kernel provider. NVIDIA kernel params live here so all
# boot.kernelParams stay in one place.
#
# The "latest" provider always gets its own specialisation (unless it's
# already the default), so the newest mainline kernel is selectable at boot
# time regardless of which kernelProvider you're currently running.
#
# NOTE: per-host `kernelProvider` assignments (in hosts.nix or the host
# module) must use `lib.mkDefault`, e.g.:
#
#   kernelProvider = lib.mkDefault "lts";
#
# This keeps the specialisation's plain assignment below able to win
# without needing mkForce, and keeps the priority hierarchy clean:
# host defaults -> specialisation overrides.
{
  flake.modules.nixos.kernel = { config, lib, pkgs, inputs, ... }:
    let
      kernelProviders = [ "xddxdd" "chaotic" "latest" "lts" "zen" "xanmod" ];
      # Per-provider config, shared between the default entry and every
      # specialisation so there's only one place to edit per kernel.
      providerConfig = provider: lib.mkMerge [
        (lib.mkIf (provider == "xddxdd") {
          nixpkgs.overlays = [ inputs."nix-cachyos-kernel".overlays.pinned ];
          boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v3;
          nix.settings.substituters = [ "https://attic.xuyh0120.win/lantian" ];
          nix.settings.trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
        })
        (lib.mkIf (provider == "chaotic") {
          boot.kernelPackages = pkgs.linuxPackages_cachyos;
          hardware.nvidia.package = lib.mkDefault pkgs.nvidia_cachyos;
        })
        (lib.mkIf (provider == "latest") {
          boot.kernelPackages = pkgs.linuxPackages_latest;
        })
        (lib.mkIf (provider == "lts") {
          boot.kernelPackages = pkgs.linuxPackages;
        })
        (lib.mkIf (provider == "zen") {
          boot.kernelPackages = pkgs.linuxPackages_zen;
        })
        (lib.mkIf (provider == "xanmod") {
          boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
        })
      ];
    in
    {
      options.kernelProvider = lib.mkOption {
        type = lib.types.enum kernelProviders;


                                      default = "zen";


        description = "Kernel provider used for the default (non-specialised) boot entry.";
      };
      config = lib.mkMerge [
        # --- Shared sysctl / kernel params (including NVIDIA) ---
        {
          boot.kernel.sysctl = {
            "vm.max_map_count" = 2147483642; # Hogwarts Legacy / large games
            "fs.file-max" = 2097152;
            "vm.nr_hugepages" = 0; # Let THP handle it dynamically
            "kernel.sched_autogroup_enabled" = 0; # Better for gaming workloads
            "vm.swappiness" = 100; # zram-only: prefer fast RAM swap early (see modules/zram.nix)
          };
          boot.kernelParams = [
            "transparent_hugepage=always"
          ] ++ lib.optionals config.hasNvidia [
            "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
            "nvidia-drm.modeset=1"
            "nvidia-drm.fbdev=1"
          ];
        }
        # --- Default boot entry: whichever provider kernelProvider is set to ---
        (providerConfig config.kernelProvider)
        # --- Single specialisation: always offer the latest mainline kernel ---
        # Plain assignment here beats a mkDefault at the host layer, so no
        # mkForce is needed. If some future definition needs to override this
        # specialisation's choice, it still can.
        (lib.mkIf (config.kernelProvider != "latest") {
          specialisation.latest.configuration.kernelProvider = "latest";
        })
      ];
    };
}

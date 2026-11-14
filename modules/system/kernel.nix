# /.dotfiles/modules/system/kernel.nix
# Switchable kernel provider. NVIDIA kernel params live here so all
# boot.kernelParams stay in one place.
#
# The "lts" provider always gets its own specialisation (unless it's
# already the default), so there's a fallback kernel to boot when the
# current kernelProvider breaks (see the NOTE above the specialisation).
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
  flake.modules.nixos.kernel = { config, options, lib, pkgs, inputs, ... }:
    let
      kernelProviders = [ "chaotic" "latest" "lts" "zen" "xanmod" ];
      # Per-provider config, shared between the default entry and every
      # specialisation so there's only one place to edit per kernel.
      providerConfig = provider: lib.mkMerge [
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


                                      default = "xanmod";


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
            "vm.swappiness" = 100; # zram-only: prefer fast RAM swap early (see modules/system/zram.nix)
            "kernel.split_lock_mitigate" = 0; # Intel: stop split-lock slowdowns/stutter in some games
            "kernel.nmi_watchdog" = 0;
            "vm.page-cluster" = 0; # zram: swap in one page at a time, not 8
            "vm.watermark_boost_factor" = 0;
            "vm.watermark_scale_factor" = 125;
          };
          boot.kernelParams = [
            "transparent_hugepage=always"
            "nowatchdog"
          ] ++ lib.optionals config.hasNvidia [
            "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
            "nvidia-drm.modeset=1"
            "nvidia-drm.fbdev=1"
          ];
          boot.kernelModules = [ "ntsync" ];
          services.udev.extraRules = ''
            KERNEL=="ntsync", MODE="0660", TAG+="uaccess"
          '';
        }
        # --- sched_ext CPU scheduler: scx_lavd ---
        # Swaps the kernel's CPU scheduler for scx_lavd, the latency-focused
        # one CachyOS ships for gaming. Needs a 6.12+ kernel with sched_ext,
        # which every kernelProvider (LTS included) has. If it misbehaves the
        # kernel drops back to its own scheduler by itself.
        # Unstable replaced `services.scx` with `services.scx-loader` (the
        # daemon behind CachyOS's scx-manager; `scxctl` switches schedulers
        # live); 26.05 still has `services.scx`. Drop the else branch once
        # nixpkgs-stable has scx-loader too.
        (if options.services ? scx-loader then {
          services.scx-loader = {
            enable = true;
            config.default_sched = "scx_lavd";
          };
        } else {
          services.scx = {
            enable = true;
            scheduler = "scx_lavd";
          };
        })
        # --- Default boot entry: whichever provider kernelProvider is set to ---
        # --- Single specialisation: Always offer the LTS kernel ---
# NOTE: LTS is the fallback specialization. Kernels Zen, Xanmod, both CachyOS builds and Latest all track the same recent upstream release. An upstream regression, or an out-of-tree module like nvidia or zfs failing to build against a new release, will often hit all of them at once. LTS is the only kernel with a separate upstream branch.

        (providerConfig config.kernelProvider)
        (lib.mkIf (config.kernelProvider != "lts") {
          specialisation.lts.configuration.kernelProvider = "lts";
        })
      ];
    };
}

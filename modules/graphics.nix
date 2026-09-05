# /.dotfiles/modules/graphics.nix
# NOTE:GPU/Vulkan/VA-API setup. NVIDIA-specific bits are gated behind `hasNvidia`
# (defined here, set per-host in modules/hosts.nix) so hosts without an
# NOTE:NVIDIA card — e.g. the laptop — get plain Mesa/Intel graphics instead.
{
  flake.modules.nixos.graphics = { config, lib, pkgs, ... }: {
    options.hasNvidia = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether this host has an NVIDIA GPU. Gates the NVIDIA driver, kernel params, and initrd modules across graphics.nix, kernel.nix, and bootloader.nix.";
    };
    config = lib.mkMerge [
      # --- Shared, GPU-vendor-agnostic ---
      {
        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };
      }
      # --- NVIDIA-only (desktop) ---
      (lib.mkIf config.hasNvidia {
        hardware.graphics.extraPackages = with pkgs; [
          nvidia-vaapi-driver
          libva-vdpau-driver
          libvdpau-va-gl
        ];
        hardware.graphics.extraPackages32 = with pkgs; [
          pkgs.driversi686Linux.libva-vdpau-driver
        ];
        services.xserver.videoDrivers = [ "nvidia" ];
        hardware.nvidia = {
          modesetting.enable = true;
          powerManagement = {
            enable = true;
            finegrained = false; # PRIME offload only; keep false on desktop
          };
          # Open vs. closed kernel modules, keyed to kernelProvider (see
          # kernel.nix): the closed/proprietary module's nv-linux.h
          # compatibility shim fails to compile against the CachyOS-based
          # kernels ("xddxdd", "chaotic") — a gpio_device_get_chip() const
          # mismatch — so those two need the open modules. "zen"/"xanmod"
          # stay on closed since they build fine and it's the more
          # conservative/default-recommended choice on stock kernels.
          # Note: "xddxdd" has a separate, unrelated build failure (a Nix
          # store-purity error referencing the kernel -dev output) that
          # this open/closed switch alone may not resolve.
          open = builtins.elem config.kernelProvider [ "xddxdd" "chaotic" ];
          nvidiaSettings = true;
          # Keeps the GPU initialized even when nothing's actively using it,
          # so the driver doesn't have to re-init (adding a beat of latency)
          # the next time something touches the GPU — first app launch,
          # first CUDA/compute call, nvidia-smi, etc. Minor tradeoff: GPU
          # stays in a slightly higher power/thermal state at idle instead
          # of dropping all the way down. Not tied to any specific kernel
          # provider — this is a standing preference, independent of open/closed.
          nvidiaPersistenced = true;
          # Driver package selection — pick one:
          package = config.boot.kernelPackages.nvidiaPackages.latest; # tracks newest driver automatically as nixpkgs updates

          #package = config.boot.kernelPackages.nvidiaPackages.production; # more conservative branch, fewer surprises
          # Exact pin, for reproducibility (update sha256 values when bumping version):
          #package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
          #  version = "610.43.02";
          #  sha256_64bit = "sha256:0qvllxnb20arjhw3bxdz0hw521di9ib75hldzx97gpscpdaa0d1h";
          #  sha256_aarch64 = "sha256:0qvllxnb20arjhw3bxdz0hw521di9ib75hldzx97gpscpdaa0d1h";
          #  openSha256 = "sha256-hP5NVZZ4vGsACHLmUDKq4uckpd/kn1GxCSYnnJfAuBs=";
          #  settingsSha256 = "sha256-0YAhufRgjDW+uR+kjaTb154fibpcDw8QowfrucoZsKE=";
          #  persistencedSha256 = "sha256-Whgv9X+v2fRhzliOl2LzltY9v1SxDafFfv3IUPqj/hk=";
          #};

        };
        # Force max GPU performance mode at boot
        systemd.services.nvidia-performance = {
          description = "Set NVIDIA GPU to maximum performance mode";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/run/current-system/sw/bin/nvidia-smi -pm 1";
          };
        };
        environment.sessionVariables = {
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          LIBVA_DRIVER_NAME = "nvidia";
          GBM_BACKEND = "nvidia-drm";
          VDPAU_DRIVER = "nvidia";
          __GL_GSYNC_ALLOWED = "1";
          __GL_VRR_ALLOWED = "1";
          WLR_NO_HARDWARE_CURSORS = "1";
          NVD_BACKEND = "direct"; # Direct backend avoids the EGL round-trip; generally the more reliable path
          GST_VAAPI_ALL_DRIVERS = "1"; # Optional: makes gstreamer's VAAPI plugin actually pick nvidia
        };
      })
      # --- Intel-only (laptop) ---
      (lib.mkIf (!config.hasNvidia) {
        services.xserver.videoDrivers = [ "modesetting" ];
        hardware.graphics.extraPackages = with pkgs; [
          intel-media-driver # VA-API for Broadwell+ iGPUs (UHD Graphics)
        ];
        environment.sessionVariables = {
          LIBVA_DRIVER_NAME = "iHD";
        };
      })
    ];
  };
}

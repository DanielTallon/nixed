# /.dotfiles/modules/system/nvidia.nix
# NOTE:GPU/Vulkan/VA-API setup. NVIDIA-specific bits are gated behind `hasNvidia`
# (defined here, set per-machine in hosts/<host>/gpu.nix, which the bootstrap
# NOTE:app writes by detecting the GPU) so hosts without an NVIDIA card get
# plain Mesa/Intel graphics instead.
{
  flake.modules.nixos.nvidia = { config, lib, pkgs, ... }: {
    options.hasNvidia = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether this host has an NVIDIA GPU. Gates the NVIDIA driver, kernel params, and initrd modules across nvidia.nix, kernel.nix, and bootloader.nix. Set per-machine in hosts/<host>/gpu.nix.";
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
          # kernel ("chaotic") — a gpio_device_get_chip() const
          # mismatch — so it needs the open modules. "zen"/"xanmod"
          # stay on closed since they build fine and it's the more
          # conservative/default-recommended choice on stock kernels.
          open = config.kernelProvider == "chaotic";
          nvidiaSettings = true;
          # Keeps the GPU initialized even when nothing's actively using it,
          # so the driver doesn't have to re-init (adding a beat of latency)
          # the next time something touches the GPU — first app launch,
          # first CUDA/compute call, nvidia-smi, etc. Minor tradeoff: GPU
          # stays in a slightly higher power/thermal state at idle instead
          # of dropping all the way down.
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
          after = [ "systemd-modules-load.service" ];
          # Skip (not fail) when no NVIDIA GPU is present, e.g. in a VM or on
          # a machine without an NVIDIA card. /proc/driver/nvidia only exists
          # once the nvidia kernel module has loaded, and the module refuses
          # to load when it finds no GPU. On the desktop the module is loaded
          # in the initrd, so this is always true there by multi-user.target.
          unitConfig.ConditionPathExists = "/proc/driver/nvidia";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/run/current-system/sw/bin/nvidia-smi -pm 1";
          };
        };
        # --- VRAM Warning Notification ---
        # When the card runs out of video memory, the compositor can't get new
        # window buffers ("Failed to allocate NVKMS memory for GEM object" in
        # the kernel log) and a game's window stops updating while the game
        # keeps running underneath. This checks once a minute and sends one
        # desktop notification when VRAM use crosses 90%, early enough to save
        # and restart the game. It re-arms once use drops back below 85%, so a
        # long session hovering near the line doesn't send a stream of them.
        systemd.user.services.vram-warning = {
          description = "Warn when NVIDIA VRAM is nearly full";
          unitConfig.ConditionPathExists = "/proc/driver/nvidia";
          path = with pkgs; [ coreutils gawk libnotify procps ];
          serviceConfig.Type = "oneshot";
          script = ''
            smi=/run/current-system/sw/bin/nvidia-smi
            read -r used total < <($smi --query-gpu=memory.used,memory.total \
              --format=csv,noheader,nounits | awk -F', ' 'NR==1 {print $1, $2}')
            [ -n "$total" ] && [ "$total" -gt 0 ] || exit 0
            pct=$((used * 100 / total))
            flag="$XDG_RUNTIME_DIR/vram-warning.sent"

            if [ "$pct" -lt 85 ]; then
              rm -f "$flag"
              exit 0
            fi
            [ "$pct" -ge 90 ] && [ ! -e "$flag" ] || exit 0

            # The three biggest users, by process name.
            top=$($smi --query-compute-apps=pid,used_memory \
              --format=csv,noheader,nounits | sort -t, -k2 -n -r | head -3 |
              while IFS=', ' read -r pid mib; do
                name=$(ps -o comm= -p "$pid" 2>/dev/null || echo "pid $pid")
                printf '%s: %s MiB\n' "$name" "$mib"
              done)

            notify-send --urgency=critical --app-name="VRAM" \
              --icon=dialog-warning \
              "GPU memory at $pct% ($used of $total MiB)" \
              "Save your work. A full card can freeze game windows.
            $top"
            touch "$flag"
          '';
        };
        systemd.user.timers.vram-warning = {
          description = "Check NVIDIA VRAM use every minute";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnActiveSec = "1min";
            OnUnitActiveSec = "1min";
            AccuracySec = "10s";
          };
        };
        environment.sessionVariables = {
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          LIBVA_DRIVER_NAME = "nvidia";
          GBM_BACKEND = "nvidia-drm";
          VDPAU_DRIVER = "nvidia";
          __GL_GSYNC_ALLOWED = "1";
          __GL_VRR_ALLOWED = "1";
          __GL_SHADER_DISK_CACHE_SIZE = "12000000000"; # 12 GB
          WLR_NO_HARDWARE_CURSORS = "1";
          NVD_BACKEND = "direct"; # Direct backend avoids the EGL round-trip; generally the more reliable path
          GST_VAAPI_ALL_DRIVERS = "1"; # Optional: makes gstreamer's VAAPI plugin actually pick nvidia
        };
      })
      # --- Intel-only (nixos-stable) ---
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

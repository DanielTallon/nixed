# /.dotfiles/modules/vm.nix
# Virtual machines: libvirt + virt-manager, and VM Curator (drives QEMU
# directly, no libvirt), with UEFI firmware where VM Curator can find it and
# optional single-GPU passthrough (custom.vm.gpuPassthrough, off by default).
{
  flake.modules.nixos.vm = { config, lib, pkgs, pkgs-unstable, username, ... }:
    let
      cfg = config.custom.vm;

      # In nixpkgs-unstable, not in 26.05, so the stable host takes it from pkgs-unstable.
      vm-curator = pkgs.vm-curator or pkgs-unstable.vm-curator;

      # Secure Boot capable, 4M, with a Microsoft-keys VARS template (Windows 11).
      ovmf = pkgs.OVMFFull.fd;
    in
    {
      options.custom.vm.gpuPassthrough = {
        enable = lib.mkEnableOption "IOMMU + VFIO for VM Curator's single-GPU passthrough";

        iommu = lib.mkOption {
          type = lib.types.enum [ "intel" "amd" ];
          default = "intel";
          description = "CPU vendor, decides the IOMMU kernel parameters.";
        };

        gpuDriver = lib.mkOption {
          type = lib.types.str;
          default = "nvidia";
          description = "Host GPU driver that vfio-pci must load ahead of.";
        };
      };

      config = lib.mkMerge [
        {
          # --- libvirt / virt-manager (moved from configuration.nix) ---
          virtualisation.libvirtd = {
            enable = true;
            onShutdown = "shutdown"; # cleanly power VMs off instead of suspending
            onBoot = "ignore";       # don't auto-start/resume anything at boot
            qemu = {
              package = pkgs.qemu_kvm;
              swtpm.enable = true;   # TPM 2.0 for Windows 11 guests in virt-manager
            };
          };

          programs.virt-manager.enable = true;

          # USB redirection over SPICE
          virtualisation.spiceUSBRedirection.enable = true;

          # Make sure libvirt's "default" NAT network is autostarted and running
          systemd.services.libvirt-default-network = {
            description = "Ensure libvirt default network is active";
            after = [ "libvirtd.service" ];
            requires = [ "libvirtd.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            path = [ config.virtualisation.libvirtd.package pkgs.gnugrep ];
            script = ''
              # Nothing to do if the network was never defined
              virsh net-info default >/dev/null 2>&1 || exit 0

              virsh net-autostart default
              virsh net-info default | grep -q '^Active:.*yes' || virsh net-start default
            '';
          };

          # --- VM Curator ---
          environment.systemPackages = [
            vm-curator
            pkgs.qemu        # full QEMU: launch.sh calls qemu-system-* from PATH, and
                             # the retro profiles need non-x86 emulators (ppc, m68k...)
            pkgs.swtpm       # TPM 2.0 for Windows 11 guests
            pkgs.virt-viewer # spice-app display (clipboard sharing)
            pkgs.passt       # passt network backend
          ];

          # UEFI firmware. VM Curator's only NixOS path is
          # /run/libvirt/nix-ovmf/OVMF_CODE.fd, but libvirt links QEMU's
          # edk2-*.fd names there now, so it never matches and VM Curator falls
          # back to a path that doesn't exist. Expose OVMFFull under the Debian
          # 4M names it does check; launch.sh then points at stable paths that
          # survive garbage collection.
          systemd.tmpfiles.rules = [
            "d  /usr/share/OVMF 0755 root root -"
            "L+ /usr/share/OVMF/OVMF_CODE_4M.fd         - - - - ${ovmf}/FV/OVMF_CODE.fd"
            "L+ /usr/share/OVMF/OVMF_VARS_4M.fd         - - - - ${ovmf}/FV/OVMF_VARS.fd"
            "L+ /usr/share/OVMF/OVMF_CODE_4M.secboot.fd - - - - ${ovmf}/FV/OVMF_CODE.fd"
            "L+ /usr/share/OVMF/OVMF_VARS_4M.ms.fd      - - - - ${ovmf}/FV/OVMF_VARS.ms.fd"
          ];

          # Lists merge with the user block in configuration.nix
          users.users.${username}.extraGroups = [ "libvirtd" "kvm" ];
        }

        # --- Single-GPU passthrough ---
        # Declarative version of VM Curator's "System Setup" wizard. Don't run
        # the wizard on NixOS: it writes /etc/modprobe.d and /etc/modules-load.d
        # by hand and looks for mkinitcpio/dracut, none of which applies here.
        (lib.mkIf cfg.gpuPassthrough.enable {
          boot.kernelParams =
            lib.optional (cfg.gpuPassthrough.iommu == "intel") "intel_iommu=on"
            ++ [ "iommu=pt" ];

          boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" ];

          # No vfio-pci ids on purpose: the host keeps the GPU at boot and the
          # per-VM start script hands it over (and back) at launch time.
          boot.extraModprobeConfig = ''
            softdep ${cfg.gpuPassthrough.gpuDriver} pre: vfio-pci
            options vfio_pci disable_vga=1 disable_idle_d3=1
          '';

          environment.systemPackages = [ pkgs.pciutils ]; # lspci, for checking IOMMU groups
        })
      ];
    };
}

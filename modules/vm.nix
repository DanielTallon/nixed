# /.dotfiles/modules/vm.nix
# Virtual machines: libvirt + virt-manager, and VM Curator (drives QEMU
# directly, no libvirt), with UEFI firmware where VM Curator can find it and
# optional single-GPU passthrough (custom.vm.gpuPassthrough, off by default).
{
  flake.modules.nixos.vm = { config, lib, pkgs, pkgs-unstable, username, ... }:
    let
      cfg = config.custom.vm;

      # In nixpkgs-unstable, not in 26.05, so the stable host takes it from pkgs-unstable.
      # Patched so --install boots the disk first and the ISO only as a
      # fallback: the installer's reboot happens inside the same QEMU process,
      # and upstream's `-boot d` sent every finished install straight back
      # into the installer.
      vm-curator = (pkgs.vm-curator or pkgs-unstable.vm-curator).overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ installBootDiskFirstPatch ];
      });

      # Blank context lines are left empty (not a lone space) so formatters
      # can't break them; GNU patch reads an empty hunk line as blank context.
      installBootDiskFirstPatch = pkgs.writeText "vm-curator-install-boot-disk-first.patch" ''
          diff --git a/src/vm/create.rs b/src/vm/create.rs
          index 252f9f4..6f7af27 100644
          --- a/src/vm/create.rs
          +++ b/src/vm/create.rs
          @@ -1310,6 +1310,15 @@ fn build_qemu_command_with_os_impl<'a>(
               let needs_uefi = config.uefi || is_windows_11(os_profile);
               let normal_uefi_disk_boot =
                   needs_uefi && matches!(install_media, InstallMedia::None) && !boot_from_floppy;
          +    // The guest reboots inside the same QEMU process when the installer
          +    // finishes, so `-boot d` would send it straight back into the installer.
          +    // For the --install ISO, rank the (still empty) disk first instead: OVMF
          +    // finds nothing to boot there and falls through to the CD-ROM, and once
          +    // the installer has written a bootloader the reboot lands on the disk.
          +    let uefi_install_disk_first = needs_uefi
          +        && matches!(install_media, InstallMedia::Iso(None))
          +        && !is_intel_macos_vm
          +        && floppy_path.is_none();

               // Emulator
               args.push(config.emulator.clone());
          @@ -1453,7 +1462,7 @@ fn build_qemu_command_with_os_impl<'a>(
                               } else {
                                   &config.disk_interface
                               };
          -                    if normal_uefi_disk_boot && disk_if == "virtio" {
          +                    if (normal_uefi_disk_boot || uefi_install_disk_first) && disk_if == "virtio" {
                                   args.push("-global virtio-blk-pci.bootindex=0".to_string());
                                   disk_has_bootindex = true;
                               }
          @@ -1503,8 +1512,13 @@ fn build_qemu_command_with_os_impl<'a>(
                                   // No -boot d for macOS (OpenCore handles boot)
                               } else {
                                   args.push(format!("-drive file={},media=cdrom,index=1", iso_ref));
          -                        // Boot from CD-ROM
          -                        args.push("-boot d".to_string());
          +                        if uefi_install_disk_first && disk_has_bootindex {
          +                            // Disk first, CD-ROM as the fallback (see above)
          +                            args.push("-global ide-cd.bootindex=1".to_string());
          +                        } else {
          +                            // Boot from CD-ROM
          +                            args.push("-boot d".to_string());
          +                        }
                               }
                           }
                       }
          diff --git a/src/vm/tests/create.rs b/src/vm/tests/create.rs
          index 3f3907b..7048425 100644
          --- a/src/vm/tests/create.rs
          +++ b/src/vm/tests/create.rs
          @@ -277,7 +277,7 @@ fn test_build_qemu_command_uefi_explicit_floppy_boot_does_not_force_disk() {
           }

           #[test]
          -fn test_build_qemu_command_uefi_cdrom_still_prefers_cdrom() {
          +fn test_build_qemu_command_uefi_install_prefers_disk_then_cdrom() {
               let config = WizardQemuConfig {
                   uefi: true,
                   disk_interface: "virtio".to_string(),
          @@ -287,8 +287,32 @@ fn test_build_qemu_command_uefi_cdrom_still_prefers_cdrom() {
               let cmd =
                   build_qemu_command_with_os(&config, "disk.qcow2", &InstallMedia::Iso(None), None, None);

          +    assert!(cmd.contains("-global virtio-blk-pci.bootindex=0"));
          +    assert!(cmd.contains("-global ide-cd.bootindex=1"));
          +    assert!(!cmd.contains("-boot d"));
          +    assert!(!cmd.contains("-boot order=c,strict=on"));
          +    assert!(!cmd.contains("-boot strict=on"));
          +}
          +
          +#[test]
          +fn test_build_qemu_command_uefi_cdrom_still_prefers_cdrom() {
          +    let config = WizardQemuConfig {
          +        uefi: true,
          +        disk_interface: "virtio".to_string(),
          +        ..WizardQemuConfig::default()
          +    };
          +
          +    let cmd = build_qemu_command_with_os(
          +        &config,
          +        "disk.qcow2",
          +        &InstallMedia::Iso(Some("\"$2\"")),
          +        None,
          +        None,
          +    );
          +
               assert!(cmd.contains("-boot d"));
               assert!(!cmd.contains("-global virtio-blk-pci.bootindex=0"));
          +    assert!(!cmd.contains("-global ide-cd.bootindex=1"));
               assert!(!cmd.contains("-boot order=c,strict=on"));
               assert!(!cmd.contains("-boot strict=on"));
           }
        '';

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
            "L+ /usr/share/OVMF/OVMF_CODE_4M.secboot.fd - - - - ${ovmf}/FV/OVMF_CODE.fd"
            # VARS are templates VM Curator copies into each VM, and the copy
            # keeps the source's mode. Store files are 0444, so use real 0644
            # copies here or every new UEFI VM gets an unwritable OVMF_VARS.fd.
            "C+ /usr/share/OVMF/OVMF_VARS_4M.fd         - - - - ${ovmf}/FV/OVMF_VARS.fd"
            "z  /usr/share/OVMF/OVMF_VARS_4M.fd         0644 root root -"
            "C+ /usr/share/OVMF/OVMF_VARS_4M.ms.fd      - - - - ${ovmf}/FV/OVMF_VARS.ms.fd"
            "z  /usr/share/OVMF/OVMF_VARS_4M.ms.fd      0644 root root -"
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

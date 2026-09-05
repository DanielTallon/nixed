# /.dotfiles/modules/configuration.nix
# Core system settings.
# NOTE:Host-specific values (hostname, stateVersion, cpuFreqGovernor) live in hosts/desktop.nix
{
  flake.modules.nixos.core = { config, pkgs, lib, username, ... }: {
    # --- Nix Settings ---
    nix.settings = {
      warn-dirty = false;
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      substituters = [ "https://nix-gaming.cachix.org" ];
      trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
    };

    # --- Nixpkgs Configuration ---
    nixpkgs.config.permittedInsecurePackages = [
      "pnpm-10.29.2"
      "electron-40.10.5"
    ];

    # --- Networking ---
    networking.networkmanager.enable = true;

    # --- Locale & Time ---
    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    # --- Display Server ---
    services.xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    # --- Autologin ---
    services.displayManager.autoLogin = {
      enable = true;
      user = username;
    };

    # --- Bluetooth ---
    hardware.bluetooth.enable = true;

    # --- CPU MicroCode ---
    hardware.cpu.intel.updateMicrocode = true;

    # --- KWallet / PAM ---
    security.pam.services.${username}.kwallet.enable = true;
    security.pam.services.sddm.kwallet.package = pkgs.kdePackages.kwallet-pam;

    # --- Audio ---
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # --- Wayland Support ---
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];

      config = {
        common = {
          default = [ "kde" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        };
        kde = {
          default = [ "kde" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        };
      };
    };
    # --- Printing ---
    services.printing.enable = true;

    # --- iOS device support ---
    services.usbmuxd = {
      enable = true;
      package = pkgs.usbmuxd2;
    };
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        workstation = true;
        hinfo = true;
      };
    };

    # --- Steam Shaders Set To Use Multicore Setup ---
    systemd.user.services.steam-shader-config = {
      description = "Configure Steam shader preprocessing threads";
      wantedBy = [ "default.target" ];
      path = with pkgs; [ coreutils gnugrep ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        THREADS=$(nproc)
        # Reserve 4 threads for the system, minimum 4 for Steam
        STEAM_THREADS=$((THREADS - 4))
        if [ $STEAM_THREADS -lt 4 ]; then
          STEAM_THREADS=4
        fi

        # Standard Steam
        mkdir -p ~/.local/share/Steam
        echo "unShaderBackgroundProcessingThreads $STEAM_THREADS" > ~/.local/share/Steam/steam_dev.cfg

        # Symlink location (often used by Steam)
        mkdir -p ~/.steam/steam
        echo "unShaderBackgroundProcessingThreads $STEAM_THREADS" > ~/.steam/steam/steam_dev.cfg
      '';
    };

    # --- Virtual Machine ---
    # Enable libvirtd and QEMU/KVM
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        # swtpm.enable = true;
      };
    };

    # Enable the Virt-manager GUI
    programs.virt-manager.enable = true;

    # Enable USB redirection and SPICE
    virtualisation.spiceUSBRedirection.enable = true;
    users.groups.usbmux = { };

    # --- User ---
    users.users.${username} = {
      isNormalUser = true;
      group = username;
      description = "User";
      extraGroups = [ "networkmanager" "wheel" "usbmux" "libvirtd" ];
    };

    users.groups.${username} = { };

  };
}

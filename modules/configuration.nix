# /.dotfiles/modules/configuration.nix
# Core system settings.
# NOTE:Host-specific values (hostname, stateVersion, cpuFreqGovernor) live in modules/hosts.nix
{
  flake.modules.nixos.core = { config, options, pkgs, lib, username, ... }: {
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

    # --- Remove Discover’s Update. Can’t install system updates anyway ---
    environment.plasma6.excludePackages = [ pkgs.kdePackages.discover ];

    #---Allow for reading backups from Windows ---
    boot.supportedFilesystems = [ "ntfs" ];

    # --- Networking ---
    networking.networkmanager.enable = true;
    # Lets devices on local network find each other and their services without DNS server.
    # Unstable moved publishing to the freeform `settings`; 26.05 still has `publish`.
    # Drop the else branch once nixpkgs-stable has `settings` too.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
    } // (if options.services.avahi ? settings then {
      settings.publish = {
        disable-publishing = false;
        publish-workstation = true;
        publish-hinfo = true;
      };
    } else {
      publish = {
        enable = true;
        workstation = true;
        hinfo = true;
      };
    });

    # --- DNS ---
    # Use Cloudflare/Google for every lookup instead of whatever DNS the
    # network hands out, so a filtering DNS server (at work) is never asked.
    # Lookups go through systemd-resolved over DNS-over-TLS (port 853), which
    # also gets past networks that intercept plain DNS on port 53.
    # "opportunistic" falls back to plain DNS to these same servers if a
    # network blocks 853; "true" would refuse instead and leave you offline.
    # Local names still work: Avahi handles .local, and Tailscale's MagicDNS
    # registers itself with resolved.
    # Don't pass the network's DNS servers on to resolved. mkForce because
    # enabling resolved sets this to "systemd-resolved" itself.
    networking.networkmanager.dns = lib.mkForce "none";
    # dns = "none" only covers resolv.conf. NetworkManager still hands each
    # connection's DNS to resolved directly unless this is off too.
    networking.networkmanager.settings.main.systemd-resolved = false;
    services.resolved = {
      enable = true;
      settings.Resolve = {
        DNS = [
          "1.1.1.1#cloudflare-dns.com"
          "1.0.0.1#cloudflare-dns.com"
          "8.8.8.8#dns.google"
          "8.8.4.4#dns.google"
        ];
        FallbackDNS = [ ]; # no servers beyond the ones above
        DNSOverTLS = "opportunistic";
        Domains = [ "~." ]; # send every domain to the servers above
        MulticastDNS = false; # Avahi does mDNS
      };
    };

    # Clear a PID file left behind by a crashed instance before starting
    systemd.services.avahi-daemon.serviceConfig = {
      ExecStartPre = [ "-${pkgs.coreutils}/bin/rm -f /run/avahi-daemon/pid" ];
      Restart = "on-failure";
    };

    # --- Locale & Time ---
    # Defaults only (mkDefault): hosts/<host>/locale.nix overrides them. The
    # nixed installer writes that file from its timezone/language/keyboard
    # review screen; otherwise it's { } and these apply.
    time.timeZone = lib.mkDefault "America/New_York";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    # Every LC_* follows the default locale.
    i18n.extraLocaleSettings = lib.genAttrs [
      "LC_ADDRESS"
      "LC_IDENTIFICATION"
      "LC_MEASUREMENT"
      "LC_MONETARY"
      "LC_NAME"
      "LC_NUMERIC"
      "LC_PAPER"
      "LC_TELEPHONE"
      "LC_TIME"
    ] (_: lib.mkDefault config.i18n.defaultLocale);

    # --- Display Server ---
    services.xserver = {
      enable = true;
      xkb = {
        layout = lib.mkDefault "us";
        variant = lib.mkDefault "";
      };
    };

    # --- Autologin ---
    services.displayManager.autoLogin = {
      enable = true;
      user = username;
    };

    # --- Bluetooth ---
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        Experimental = true;        # AirPods battery level in Plasma
        # ControllerMode = "bredr"; # uncomment if AirPods won't connect or keep dropping
      };
    };

    services.blueman.enable = true;  # pairing GUI; skip it if you use GNOME or KDE

    # --- Set ~/.local/bin onto your PATH ---
    environment.localBinInPath = true;


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
      wireplumber.enable = true;
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

        # Steam's real data dir. ~/.steam/steam is a symlink to it that Steam
        # makes on its first run, so only write here and never create
        # ~/.steam/steam ourselves: if it already exists as a plain folder,
        # Steam can't make its link and stops with "Couldn't set up Steam
        # data". (An older version of this service did exactly that.)
        # On my system: 24 shader threads that ends once the shaders are processed
        steam_root="$HOME/.local/share/Steam"
        mkdir -p "$steam_root"
        echo "unShaderBackgroundProcessingThreads $STEAM_THREADS" > "$steam_root/steam_dev.cfg"

        # Repair: ~/.steam/steam is a plain folder. Move its contents into
        # the real data dir (keeping what's already there), replace it with
        # the link Steam expects, and drop ~/.steam/bin so Steam rebuilds it.
        if [ -d "$HOME/.steam/steam" ] && [ ! -L "$HOME/.steam/steam" ]; then
          cp -a --update=none "$HOME/.steam/steam/." "$steam_root/"
          rm -rf "$HOME/.steam/steam" "$HOME/.steam/bin"
          ln -s ../.local/share/Steam "$HOME/.steam/steam"
        fi
      '';
    };


    # Steam: faster game installs from another PC on your network
    programs.steam.localNetworkGameTransfers.openFirewall = true;

    # Stop the PS4/PS5 controller touchpad from moving the mouse cursor
    services.udev.extraRules = ''
      ATTRS{name}=="Sony Interactive Entertainment Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ATTRS{name}=="Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ATTRS{name}=="DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '';

    # Disk write-back: fewer stalls during large writes (shader caches, game installs)
    boot.kernel.sysctl = {
      "vm.dirty_bytes" = 268435456;            # 256 MB
      "vm.dirty_background_bytes" = 67108864;  # 64 MB
      "vm.vfs_cache_pressure" = 50;
    };

    # Stop WirePlumber polling for cameras through libcamera
    services.pipewire.wireplumber.extraConfig."10-disable-libcamera" = {
      "wireplumber.profiles".main."monitor.libcamera" = "disabled";
    };





    # --- User ---
    users.users.${username} = {
      isNormalUser = true;
      group = username;
      description =
        lib.toUpper (builtins.substring 0 1 username)
        + builtins.substring 1 (-1) username;
      extraGroups = [ "networkmanager" "wheel" "usbmux" ];
    };

    users.groups.${username} = { };

  };
}

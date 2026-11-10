# /.dotfiles/modules/system/networking.nix
# NetworkManager, Avahi, encrypted DNS and LocalSend.
{
  flake.modules.nixos.networking = { options, pkgs, lib, username, ... }: {
    networking.networkmanager.enable = true;
    users.users.${username}.extraGroups = [ "networkmanager" ];

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

    # --- LocalSend ---
    # Opens TCP/UDP 53317 so phones can find this PC and send files to it.
    programs.localsend = {
      enable = true;
      openFirewall = true;
    };

    # FIX: localsend 1.18.0 won't start ("libz.so.1: cannot open shared object
    # file") because the main binary is built without zlib on its library path.
    # This applies the fix from NixOS/nixpkgs#585411 (issue #585072); it turns
    # itself off once nixpkgs sets runtimeDependencies itself.
    # TODO: delete this overlay after nixpkgs#585411 lands.
    nixpkgs.overlays = [
      (_final: prev: {
        localsend =
          if (prev.localsend.runtimeDependencies or [ ]) == [ ] then
            prev.localsend.overrideAttrs (_old: {
              runtimeDependencies = [ (prev.lib.getLib prev.zlib) ];
            })
          else
            prev.localsend;
      })
    ];
  };
}

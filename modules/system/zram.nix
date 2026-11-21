# /.dotfiles/modules/system/zram.nix
# Compressed RAM-backed swap. Pairs with vm.swappiness=100 in kernel.nix —
# with no disk swap configured, we want the kernel to reach for zram early
# since it's cheap/fast, unlike real disk swap.
#
# Also systemd-oomd, which kills a memory hog before the desktop locks up.
{
  flake.modules.nixos.zram = {
    zramSwap = {
      enable = true;
      memoryPercent = 25; # ~25% of RAM as compressed swap capacity
      algorithm = "zstd"; # better ratio than lz4, still fast on modern CPUs
    };

    # --- systemd-oomd (setup from CachyOS-Settings) ---
    # When memory pressure stays above 80% for 30s, oomd SIGKILLs the app or
    # service under the watched slice that is reclaiming the most memory.
    # `oomctl` shows what it watches; kills show up in `journalctl -u systemd-oomd`.
    #
    # Watched: system services (e.g. a runaway nix build), plus the user's
    # app.slice (apps) and background.slice. session.slice (niri, PipeWire,
    # portals) is deliberately not watched, so the desktop itself is never killed.
    #
    # Not using systemd.oomd.enableUserSlices: it also watches user.slice from
    # root, and from there oomd ignores the "avoid" marks below, so it could
    # still pick the game.
    #
    # Kill-last ("avoid") marks, picked only when nothing else is left:
    #   - games: app-steam-*.scope (modules/gaming/steam.nix)
    #   - noctalia.service, which also holds every app started from its
    #     launcher, Steam's client included (modules/desktop/niri.nix)
    systemd.slices.system.sliceConfig = {
      ManagedOOMSwap = "kill"; # zram over 90% full: kill the biggest swap user
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "80%";
    };
    systemd.user.units = {
      "app.slice" = {
        overrideStrategy = "asDropin";
        text = ''
          [Slice]
          ManagedOOMMemoryPressure=kill
          ManagedOOMMemoryPressureLimit=80%
        '';
      };
      "background.slice" = {
        overrideStrategy = "asDropin";
        text = ''
          [Slice]
          ManagedOOMMemoryPressure=kill
          ManagedOOMMemoryPressureLimit=80%
        '';
      };
    };
  };
}

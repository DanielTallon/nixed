# /.dotfiles/home-manager/wallpaper.nix
#---Starter wallpaper slideshow---
# On the first activation for a user (e.g. the first boot after the quick
# installer's stage 2):
#   1. copies PikaOS's wallpapers into ~/Pictures/Wallpaper as normal,
#      writable files (not Nix store symlinks), so you can add/remove freely
#   2. on the next Plasma login, points every desktop at that folder as a
#      slideshow: Scaled keep proportions, black solid background, random
#      order, no folder grouping, 7 minutes per picture
#
# Both steps happen ONCE. After that, nothing here touches the folder or the
# wallpaper settings again, so changes made in the folder or in System
# Settings stick. State lives in ~/.local/state/nixed/:
#   wallpaper-seeded  - seeding has been decided; delete to seed again
#   wallpaper-apply   - slideshow settings still pending for the next login
#
# Seeding is skipped if ~/Pictures/Wallpaper already exists, so an existing
# folder is never overwritten (and the wallpaper settings aren't changed).
# To opt an existing machine out entirely before switching:
#   mkdir -p ~/.local/state/nixed && touch ~/.local/state/nixed/wallpaper-seeded
{
  flake.modules.homeManager.wallpaper = { config, pkgs, lib, ... }:
    let
      # Fetched from upstream at build time rather than copied into this
      # repo. Bump rev + hash to pick up new upstream pictures (only affects
      # machines that haven't been seeded yet).
      pikaWallpapers = pkgs.fetchFromGitHub {
        owner = "PikaOS-Linux";
        repo = "pkg-pika-wallpapers";
        rev = "3ce68511b5f7146f7ac1795f7858ce8f0749debb";
        hash = "sha256-n2yzcljbBdDr0eYoU4Aborxdgy/dGYR8Uo3ok1E/0Qg=";
      };

      wallDir = "${config.home.homeDirectory}/Pictures/Wallpaper";
      stateDir = "${config.xdg.stateHome}/nixed";
    in
    {
      # 1. Seed the folder (runs during home-manager activation, at boot or
      #    on switch; before Plasma ever starts on a fresh install).
      home.activation.seedWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -e "${stateDir}/wallpaper-seeded" ]; then
          run mkdir -p "${stateDir}"
          if [ ! -e "${wallDir}" ]; then
            verboseEcho "Seeding ${wallDir} with the starter wallpapers"
            run mkdir -p "${wallDir}"
            # --no-preserve=mode: store files are read-only; make normal 644 copies
            run cp --no-preserve=mode,ownership \
              ${pikaWallpapers}/backgrounds/pika/* "${wallDir}/"
            run touch "${stateDir}/wallpaper-apply"
          fi
          run touch "${stateDir}/wallpaper-seeded"
        fi
      '';

      # 2. Apply the slideshow settings on the next Plasma login, only if
      #    step 1 just seeded the folder. Rides on plasma-manager's startup
      #    runner (same mechanism as the kickoff icon script in plasma.nix).
      #    The pre-check also stops plasma-manager from re-applying this
      #    whenever some other desktop script changes and it re-runs them all.
      programs.plasma.startup.desktopScript."nixed-wallpaper-slideshow" = {
        priority = 4; # after plasma-manager's own theme/panel scripts
        preCommands = ''
          [ -e "${stateDir}/wallpaper-apply" ] || exit 0
        '';
        text = ''
          desktops().forEach(d => {
            d.wallpaperPlugin = "org.kde.slideshow";
            d.currentConfigGroup = ["Wallpaper", "org.kde.slideshow", "General"];
            d.writeConfig("SlidePaths", "${wallDir}/");
            d.writeConfig("SlideInterval", 420);          // 0h 7m 0s
            d.writeConfig("SlideshowMode", 0);            // Order: Random
            d.writeConfig("SlideshowFoldersFirst", false); // Group by folders: off
            d.writeConfig("FillMode", 1);                 // Scaled, keep proportions
            d.writeConfig("Blur", false);                 // Background: solid color...
            d.writeConfig("Color", "#000000");            // ...black
            d.writeConfig("DynamicMode", 0);              // Light/dark: follow Plasma style
          });
        '';
        # Only clear the flag if the script actually ran (plasma-manager's
        # runner sets success=0 on any error), so a too-early login retries.
        postCommands = ''
          if [ "$success" -eq 1 ]; then rm -f "${stateDir}/wallpaper-apply"; fi
        '';
      };
    };
}

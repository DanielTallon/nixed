# /.dotfiles/modules/gaming/steam.nix
# Steam, its Proton compat tools, and the Steam-only helper tools.
# Per-game Wine DPI overrides are the home-manager half at the bottom of this
# file (custom.protonDpi).
#
# ===================== Vortex (manual setup) =====================
# Vortex isn't declared here on purpose. It's a Windows installer inside a
# Proton prefix and updates itself, and its Steam shortcut and launch options
# live in shortcuts.vdf / localconfig.vdf, which Steam rewrites. Nix would
# only fight both of them. These are the steps to set it up again:
#
#  1. Download the Vortex installer from Nexus Mods. In Steam: Add a Game >
#     Add a Non-Steam Game > pick the installer. Properties > Compatibility >
#     force Proton 11.0. Run it and install to the default location.
#  2. Point the shortcut's target at the installed Vortex.exe
#     (Program Files/Black Tree Gaming Ltd/Vortex) and rename it "Vortex".
#     Its prefix is steamapps/compatdata/<shortcut appid>/ (currently 3133531074).
#  3. Add games in Vortex by their Z:\ path. Staging folder:
#     ~/Games/Vortex/{game}. Deployment method: Symlink (the only one it offers).
#     Proton 11 stores those symlinks as Windows reparse points, which
#     Proton-Wineland reads fine in the game's own prefix.
#  4. Witcher 3 (Steam 292030) keeps running on Proton-Wineland.
#     In the Vortex prefix, make "Documents/The Witcher 3" a symlink to the
#     game prefix's copy (compatdata/292030/pfx/drive_c/users/steamuser/Documents/The Witcher 3).
#     Don't use MO2-LINT for it: its wrapper pins Wineland's /nix/store path.
#  5. Cyberpunk 2077 (in ~/Games) launch option, for CET/RED4ext:
#       WINEDLLOVERRIDES="winmm,version=n,b" %command%
#
#  Updates: let Vortex update itself. If its installer fails under Proton,
#  run the new installer in the same prefix:
#    protontricks-launch --appid 3133531074 <installer.exe>
#  After any Vortex, Proton, Wineland or game update (or a Steam file
#  verify), open Vortex and click Deploy. If mods stop loading, Purge, then
#  Deploy. Before a big Vortex version jump, back up the compatdata folder.
# =================================================================
{
  flake.modules.nixos.steam = { pkgs, inputs, ... }:
  let
    nix-packages = inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system};
  in
  {
    # --- Gameing: Steam ---
    programs.steam = {
      enable = true;
      # GameMode for the whole Steam session, so no per-game launch option is needed.
      # Registers the launcher's own PID with gamemoded right before it execs into
      # bubblewrap, so that PID becomes Steam's sandbox and stays registered until
      # Steam fully quits. Renice and core pinning are set before Steam starts, so
      # Steam and every game it launches inherit them.
      # (Preloading libgamemodeauto into Steam instead breaks steamwebhelper:
      # Steam won't start, "unexpected error during startup (0x3009)".)
      package = pkgs.steam.override {
        extraPreBwrapCmds = ''
          ${pkgs.gamemode}/bin/gamemoded -r$$ >/dev/null \
            || echo "steam: couldn't start GameMode, launching without it" >&2
        '';
      };
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      # Steam: faster game installs from another PC on your network
      localNetworkGameTransfers.openFirewall = true;
      protontricks.enable = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
#         proton-ge-bin nix-packages.proton-ge-w3rt
        nix-packages.proton-wineland
        #inputs.nix-proton-cachyos.packages.${pkgs.stdenv.hostPlatform.system}.proton-cachyos
        #run: nix flake update nix-proton-cachyos, first before uncommenting out the line above.
      ];
    };

    # --- Steam helper tools ---
    # steamtinkerlaunch brings its own xdotool, xwininfo and yad.
    environment.systemPackages = with pkgs; [
      steamtinkerlaunch
    ];

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
  };

  # --- Per-game Wine DPI (LogPixels) in Proton prefixes ---
  flake.modules.homeManager.steam = { config, lib, pkgs, ... }:
    let
      cfg = config.custom.protonDpi;
      mkDpiScript = appid: dpi: ''
        prefix="$HOME/.local/share/Steam/steamapps/compatdata/${appid}/pfx"
        if [ -d "$prefix" ]; then
          WINEPREFIX="$prefix" ${pkgs.wine64}/bin/wine reg add \
            "HKEY_CURRENT_USER\\Control Panel\\Desktop" \
            /v LogPixels /t REG_DWORD /d ${toString dpi} /f
        fi
      '';
    in {
      options.custom.protonDpi = lib.mkOption {
        type = lib.types.attrsOf lib.types.int;
        default = { };
        description = "Per-Steam-appid Wine DPI (LogPixels) overrides, applied on home-manager activation";
      };

      config.home.activation.protonDpi = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatStringsSep "\n" (lib.mapAttrsToList mkDpiScript cfg)
      );

      config.custom.protonDpi."2105600" = 192; # Larger loading window for RPG Stories
      #config.custom.protonDpi."2105600" = 96; # Default setting
      #96	100%
      #120	125%
      #144	150%
      #168	175%
      #192	200%
      #216	225%
      #240	250%
      #288	300%
    };
}

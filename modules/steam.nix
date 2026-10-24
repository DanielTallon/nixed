# /.dotfiles/modules/steam.nix
# Steam, its Proton compat tools, and the Steam-only helper tools.
# NOTE: Per-game Wine DPI overrides are a home-manager module instead:
# home-manager/proton-dpi.nix (values set in modules/hosts.nix).
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
}

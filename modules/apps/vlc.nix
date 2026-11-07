# /.dotfiles/modules/apps/vlc.nix
# VLC media player and the preferences set for it.
{
  flake.modules.nixos.vlc = { pkgs-stable, ... }: {
    environment.systemPackages = [ pkgs-stable.vlc ];
  };

  flake.modules.homeManager.vlc = { config, lib, pkgs, ... }:
    let
      # Keys in ~/.config/vlc/vlcrc, the same ones the Preferences window
      # (Show settings: All) changes.
      settings = {
        # Don't show the file name across the bottom when a video starts
        # (Subtitles / OSD > Show media title on video start).
        video-title-show = "0";
        # Keep the window at its tile size. With this on, VLC resizes the
        # window to fit the video every time it starts, which in niri makes a
        # looping video jump to a bigger size at each restart
        # (Interface > Resize interface to video size).
        qt-video-autoresize = "0";
      };
    in
    {
      # Written into vlcrc on activation (not a home.file symlink) because VLC
      # rewrites the whole file when you save in its Preferences window. Each
      # key replaces its own line, commented out or not, so the rest of the
      # file and anything set from the Preferences window stays as it is.
      home.activation.vlcSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        rc="${config.xdg.configHome}/vlc/vlcrc"
        run mkdir -p "$(dirname "$rc")"
        [ -f "$rc" ] || run touch "$rc"
        ${lib.concatStrings (lib.mapAttrsToList (key: value: ''
          if ${pkgs.gnugrep}/bin/grep -q '^#\?${key}=' "$rc"; then
            run ${pkgs.gnused}/bin/sed -i 's/^#\?${key}=.*/${key}=${value}/' "$rc"
          else
            run sh -c 'echo "${key}=${value}" >> "$1"' _ "$rc"
          fi
        '') settings)}
      '';
    };
}

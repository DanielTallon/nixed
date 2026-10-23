# /.dotfiles/home-manager/tauon/default.nix

# Tauon Music Box settings, captured from ~/.local/share/TauonMusicBox.
#
# Tauon rewrites tauon.conf itself every time it closes, so it can't be a
# read-only home.file symlink. Instead, on every rebuild the keys below are
# merged into the real file: declared keys win, anything not declared here
# (account logins, tokens, Tauon's own bookkeeping) is left alone.
# Changing a setting in the app still works, but the next rebuild resets
# any key that's declared here, so make lasting changes in this file.
#
# Close Tauon before rebuilding, or it will write its old values back on exit.
#
# Not declarable: playlists, play counts, loves, window size and most toggles
# from the right-click menus live in state.p / star.p (binary pickle files).
{
  flake.modules.homeManager.tauon = { config, pkgs, lib, ... }:
    let
      tauonDir = "${config.xdg.dataHome}/TauonMusicBox";

      # Section names are only for readability: Tauon looks keys up by name
      # anywhere in the file and rewrites its own layout on exit.
      settings = {
        audio = {
          use-pipewire = true;
          seek-interval = 15; # seconds, keyboard seek step
          playback-speed = 1.0; # 0.1 - 3.0
          cross-fade-time = 700; # ms, 200 - 2000
          use-pre-roll = false;
          pre-roll-time = 1500; # ms
          device-buffer-ms = 80;
          avoid_resampling = false;
          force-stereo-output = false;
          dsd-direct = false;
          resample-quality = 1; # 0=best, 1=medium, 2=fast, 3=fastest
          cache-limit = 2000; # MB
          network-stream = true;
          stream-buffer-size = 50; # MB
          cache-use-tmp = true;
          precache-local-files = false;
          always-ffmpeg = false;
          volume-curve = 2; # 1 = linear
          jump-start-dl = true;
        };

        locale = {
          display-language = "auto";
        };

        search = {
          separate-multi-genre = false;
        };

        tag-editor = {
          tag-editor-auto-slashes = true;
          use_lrc_instead = true; # synced lyrics go to separate .lrc files
          save_lyrics_changes_to_files = false;
          allow_overwrite_synced_with_static = false;
          show_lyrics_save_menu = true;
          synced_lyrics_editor_track_end_mode = "repeat"; # "stop", "autosave" or "full save"
        };

        playback = {
          playback-follow-cursor = false;
          back-restarts = true;
          resume-on-advance = true;
          end-queue-stop = false;
          block-suspend = false;
          allow-video-formats = true;
        };

        HiDPI = {
          ui-scale = 1.65;
          auto-scale = false;
          tracklist-y-text-offset = 0;
        };

        ui = {
          theme-name = "Carbon Copy Copy"; # file in ./themes
          transparent-style = 0; # 0=off, 1=glass
          transparency-tracklist-darkness = 0.0; # 0 - 1
          transparency-intensity = 1.0; # 0.5 - 1.5
          rounded-corners = true;
          rounded-corner-radius = 10;
          mac-style = false;
          allow-art-zoom = false;
          scroll-gallery-by-row = false;
          scroll-gallery-distance = 90;
          scroll-spectrogram = true;
          mascot-opacity = 40;
          synced-lyrics-time-offset = -150; # ms, negative shows lines earlier
          artist-list-prefers-album-artist = true;
          side-panel-info-persists = false;
          side-panel-info-selected = false;
          side-panel-info-selected-always = false;
          mini-mode-avoid-notifications = false;
          hide-queue-when-empty = true;
          enable-art-header-bar = true;
          always-art-header-bar = false;
          side-panel-style = 0; # 0=default, 1=centered
          side-panel-left = false;
          side-lyrics-art = false;
          side-lyrics-art-on-top = false;
          showcase-wide-art = false;
          absolute-track-indices = false;
          auto-hide-bottom-title = true;
          auto-show-playing = false;
          notify-include-album = true;
          show-rating-hint = false;
          drag-tab-to-unpin = true;
        };

        gallery = {
          gallery-thin-borders = false;
          increase-row-spacing = false;
          gallery-center-text = false;
        };

        fonts = {
          use-custom-fonts = false; # the font-* keys only apply when this is true
          font-main-standard = "Noto Sans, Noto Sans CJK JP, Arial,";
          font-main-medium = "Noto Sans, Noto Sans CJK JP, Arial, Medium";
          font-main-bold = "Noto Sans, Noto Sans CJK JP, Bold";
          font-main-condensed = "Noto Sans, Extra-Condensed";
          font-main-condensed-bold = "Noto Sans, Extra-Condensed Bold";
        };

        tracklist = {
          double-digit-indices = false;
          column-album-artist-fallsback = false;
          column-album-art-full-height = true;
          left-aligned-album-artist-title = false;
          tracklist-scrollbar-left = false;
        };

        transcode = {
          sync-bypass-transcode = false;
          sync-bypass-low-bitrate = true;
          radio-record-codec = "OPUS"; # OPUS, OGG, FLAC or MP3
        };

        directories = {
          sync-device-music-dir = "";
          encode-output-dir = ""; # blank = encode-output in ~/Music
          add_download_directory = "";
          playlist_folder_path = "";
          autoscan_playlist_folder = false;
        };

        app = {
          enable-remote-interface = false;
          use-gamepad = true;
          use-system-tray = false;
          hide-maximize-button = false;
          restore-window-position = true;
          mini-mode-always-on-top = false;
          enable-mpris = true;
          resume-playback-on-restart = false;
          resume-playback-on-wake = false;
          auto-dl-artist-data = true;
          "fanart.tv-cover" = false;
          "fanart.tv-artist" = false;
          "fanart.tv-background" = false;
          auto-update-playlists = true;
          write-ratings-to-tag = false;
          enable-discord-rpc = false;
          discord-card-layout = "title_artist"; # or "artist_title"
          discord-member-list-display = "artist"; # or "song"
          discord-clean-title = true;
          discord-lastfm-button = false;
          discord-show-tauon-button = true;
          discord-keep-idle = false;
          discord-litterbox-upload = false;
          auto-search-lyrics = false;
          shortcuts-ignore-keymap = false;
          alpha_key_activate_search = true;
          taskbar-status = true;
        };

        lastfm = {
          lastfm-pull-love = false;
        };

        scrobbling = {
          scrobble-radios = true;
          scrobble-jellyfin = true;
          scrobble-tidal = true;
          scrobble-subsonic = true;
          scrobble-plex = true;
        };

        network = {
          stream-bitrate = 0; # 0 = no server-side transcoding
        };

        listenalong = {
          broadcast-page-port = 7590;
        };

        chart = {
          chart-columns = 3;
          chart-rows = 3;
          chart-uses-text = true;
          chart-sorts-top-played = true;
          chart-font = "Monospace 10";
        };
      };

      # Tauon's format is "key = value" with JSON-style scalars (true/false,
      # numbers, "quoted strings"), which is exactly what toJSON emits.
      declaredConf = pkgs.writeText "tauon-declared.conf" (lib.concatStrings (lib.mapAttrsToList
        (section: keys: ''

          [${section}]
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key} = ${builtins.toJSON value}") keys)}
        '')
        settings));
    in
    {
      xdg.dataFile."TauonMusicBox/theme/Carbon Copy.ttheme".source = ./themes + "/Carbon Copy.ttheme";
      xdg.dataFile."TauonMusicBox/theme/Carbon Copy Copy.ttheme".source = ./themes + "/Carbon Copy Copy.ttheme";

      home.activation.tauonSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        conf="${tauonDir}/tauon.conf"
        run mkdir -p "${tauonDir}"

        if [ -f "$conf" ]; then
          # Keep every line of the current file whose key isn't declared,
          # then append the declared keys.
          merged="$(mktemp)"
          ${pkgs.gawk}/bin/awk '
            function keyof(line) {
              sub(/ #.*/, "", line)
              if (index(line, "=") == 0) return ""
              line = substr(line, 1, index(line, "=") - 1)
              gsub(/[ \t]/, "", line)
              return line
            }
            NR == FNR { k = keyof($0); if (k != "") declared[k] = 1; next }
            !(keyof($0) in declared)
          ' ${declaredConf} "$conf" > "$merged"
          cat ${declaredConf} >> "$merged"
          run ${pkgs.coreutils}/bin/install -m644 "$merged" "$conf"
          rm -f "$merged"
        else
          run ${pkgs.coreutils}/bin/install -m644 ${declaredConf} "$conf"
        fi

        # Custom layout editor slots. Copied, not linked, because Tauon saves this file itself.
        run ${pkgs.coreutils}/bin/install -m644 ${./custom_layouts.json} "${tauonDir}/custom_layouts.json"
      '';
    };
}

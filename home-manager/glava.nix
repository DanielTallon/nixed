#/.dotfiles/home-manager/glava.nix

{
  flake.modules.homeManager.glava = { pkgs, ... }:
    let
      tauonWithGlava = pkgs.writeShellApplication {
        name = "tauon-with-glava";
        runtimeInputs = [ pkgs.procps ];
        text = ''
          started_glava=0
          if ! pgrep -x glava >/dev/null; then
            ${pkgs.glava}/bin/glava &
            glava_pid=$!
            started_glava=1
          fi

          ${pkgs.tauon}/bin/tauon "$@"
          exit_code=$?

          if [ "$started_glava" -eq 1 ]; then
            kill "$glava_pid" 2>/dev/null || true
          fi

          exit "$exit_code"
        '';
      };
    in
    {
      home.packages = [ pkgs.glava tauonWithGlava ];

      xdg.configFile."glava/rc.glsl".text = ''
        #request mod bars

        /* Window hints */
        #request setfloating  true
        #request setdecorated false
        #request setfocused   false
        #request setmaximized false

        #request setopacity "native"
        #request setmirror false

        #request setversion 3 3
        #request setshaderversion 330

        #request settitle "GLava"

        /* Window geometry (x, y, width, height) — DP-1 primary, offset 2592,18 */
        #request setgeometry 2592 1386 3440 100

        #request setbg 00000000

        #request setxwintype "normal"
        #request addxwinstate "below"
        #request addxwinstate "sticky"
        #request addxwinstate "skip_taskbar"
        #request addxwinstate "skip_pager"

        #request setclickthrough false

        #request setsource "auto"
        #request setswap 1
        #request setinterpolate true
        #request setframerate 0
        #request setfullscreencheck false
        #request setprintframes true
        #request setsamplesize 1024
        #request setbufsize 4096
        #request setsamplerate 22050

        #request setforcegeometry true
        #request setforceraised false
        #request setbufscale 1
      '';

      xdg.dataFile."applications/tauonmb.desktop".text = ''
        [Desktop Entry]
        Version=1.1
        Comment=Ultra player for your music collection
        GenericName=Audio Player
        Keywords=Music;MP3;OGG;FLAC;OPUS;Convert;Stream;Podcast;Playlist;Last.fm;PHAzOR;Radio;
        Name=Tauon
        Exec=tauon-with-glava %U
        Icon=tauonmb
        MimeType=application/ogg;audio/x-vorbis+ogg;application/x-ogg;audio/ogg;audio/x-ogg;audio/x-opus+ogg;audio/flac;audio/x-flac;application/flac;audio/wav;audio/x-wav;audio/tta;audio/x-tta;audio/mp3;audio/x-mp3;audio/m4a;audio/x-m4a;audio/ape;audio/x-ape;x-content/audio-player;audio/scpls;audio/x-scpls;audio/x-pls;audio/m3u;application/xspf+xml
        StartupNotify=false
        StartupWMClass=Tauon Music Box
        Terminal=false
        Type=Application
        Categories=AudioVideo;Player;Audio;
        Actions=PlayPause;Previous;Next;Stop
        X-GNOME-UsesNotifications=true

        [Desktop Action PlayPause]
        Exec=tauon --no-start --play-pause
        Name=Play/Pause

        [Desktop Action Previous]
        Exec=tauon --no-start --previous
        Name=Previous Track

        [Desktop Action Next]
        Exec=tauon --no-start --next
        Name=Next Track

        [Desktop Action Stop]
        Exec=tauon --no-start --stop
        Name=Stop
      '';
    };
}

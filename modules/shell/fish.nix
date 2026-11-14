# /.dotfiles/modules/shell/fish.nix
{
  flake.modules.nixos.fish = { pkgs, pkgs-unstable, username, ... }: {
    programs.fish.enable = true;
    users.users.${username}.shell = pkgs.fish;
    environment.systemPackages = [
      pkgs.fish
      pkgs-unstable.unimatrix # the matrix rain in interactiveShellInit below
    ];

    # --- Set ~/.local/bin onto your PATH ---
    environment.localBinInPath = true;
  };

  flake.modules.homeManager.fish = { pkgs, ... }: {
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        unimatrix -f -l 'm' -a -b -c blue -s 97
        #fastfetch
        #fastfetch --config examples/25
        '';

      # Fish 4's default Ctrl+L (scrollback-push clear-screen) keeps the old
      # output in scrollback. `clear` also sends \e[3J, which wipes it too.
      functions.fish_user_key_bindings = ''
        bind ctrl-l 'clear; commandline -f repaint'
      '';

      # --- Audio helpers: `trim` and `vol` ---
      # Both print the ffmpeg command they run (dimmed), so the real command
      # is always visible. Output goes next to the original as
      # "NAME (trimmed).mp3" / "NAME (louder).mp3"; the original is never
      # touched. Run either with no arguments for usage.

      # Help for both, shown by `trim ?` or `vol ?` (or either one with
      # missing arguments).
      functions.__audio_help = ''
        set_color --bold; echo "trim: cut a song down"; set_color normal
        echo "  trim FILE START [END] [--fade SECONDS]"
        echo "    Keeps START to END, or to the end of the song if END is left out."
        echo "    Times are seconds (90) or m:ss (1:30)."
        echo "    --fade (or -f) fades out over that many seconds at the end."
        echo "    Saves \"NAME (trimmed).EXT\" next to the original."
        echo
        echo "    trim ~/Music/Song.mp3 0:05             cut off the first 5 seconds"
        echo "    trim ~/Music/Song.mp3 0:00 4:05        end the song at 4:05"
        echo "    trim ~/Music/Song.mp3 0:04 2:30 -f 5   keep 0:04-2:30, fade out over 5s"
        echo
        set_color --bold; echo "vol: check or change a song's volume"; set_color normal
        echo "  vol FILE [+dB | -dB]"
        echo "    Saves \"NAME (louder).EXT\" or \"NAME (quieter).EXT\" next to the original."
        echo
        echo "    vol ~/Music/Song.mp3        show how loud it is, and how much it can go up"
        echo "    vol ~/Music/Song.mp3 +6     louder (about twice as loud)"
        echo "    vol ~/Music/Song.mp3 -6     quieter (about half as loud)"
        echo
        echo "File names with spaces need quotes:  trim ~/Music/\"First of May.mp3\" ..."
        echo "Or type the start of the name and press Tab to fill in the rest."
      '';

      # Turns 90, 1:30 or 1:02:30 into seconds. Used by trim.
      functions.__audio_secs = ''
        set -l total 0
        for part in (string split : -- $argv[1])
            if not string match -qr '^[0-9]+(\.[0-9]+)?$' -- $part
                echo "Not a valid time: $argv[1] (use seconds like 90, or m:ss like 1:30)" >&2
                return 1
            end
            set total (math "$total * 60 + $part")
        end
        echo $total
      '';

      # Prints a file's loudest peak in dB (0 is the maximum). Used by vol.
      functions.__audio_peak = ''
        ffmpeg -hide_banner -nostats -i $argv[1] -af volumedetect -f null - 2>&1 \
            | string match -rg 'max_volume: (-?[0-9.]+) dB'
      '';

      functions.trim = {
        description = "Trim an audio file: trim FILE START [END] [--fade SECONDS]";
        body = ''
          argparse h/help 'f/fade=' -- $argv; or return
          if set -q _flag_help; or test "$argv[1]" = "?"
              __audio_help
              return
          end
          if not set -q argv[2]
              __audio_help
              return 1
          end

          set -l in $argv[1]
          if not test -f $in
              echo "trim: file not found: $in" >&2
              return 1
          end
          set -l start (__audio_secs $argv[2]); or return
          set -l out (path change-extension "" -- $in)" (trimmed)"(path extension -- $in)

          # -ss before -i: start there, and count the new file's time from 0
          set -l cmd ffmpeg -hide_banner -loglevel warning -stats -ss $argv[2] -i $in

          # Length of the new file: END - START, or (song length - START)
          # when only a fade needs it
          set -l len
          if set -q argv[3]
              set -l stop (__audio_secs $argv[3]); or return
              set len (math "$stop - $start")
              if test $len -le 0
                  echo "trim: END ($argv[3]) has to be after START ($argv[2])" >&2
                  return 1
              end
              set -a cmd -t $len
          else if set -q _flag_fade
              set -l dur (ffprobe -v error -show_entries format=duration -of csv=p=0 -i $in)
              set len (math "$dur - $start")
          end

          if set -q _flag_fade
              if not string match -qr '^[0-9]+(\.[0-9]+)?$' -- $_flag_fade; or test $_flag_fade -gt $len
                  echo "trim: --fade needs a number of seconds no longer than the new file ($len s)" >&2
                  return 1
              end
              # A fade changes the sound, so it has to re-encode (at 320k);
              # -c:v copy keeps any album art as it is
              set -l fade_start (math -s2 "$len - $_flag_fade")
              set -a cmd -af "afade=t=out:st=$fade_start:d=$_flag_fade" -b:a 320k -c:v copy
          else
              # Only cutting: copy the audio as-is, instant and lossless
              set -a cmd -c copy
          end
          set -a cmd $out

          set_color --dim; echo (string escape -- $cmd); set_color normal
          $cmd
        '';
      };

      functions.vol = {
        description = "Show or change an audio file's volume: vol FILE [+dB | -dB]";
        body = ''
          if contains -- "$argv[1]" "?" -h --help
              __audio_help
              return
          end
          if not set -q argv[1]
              __audio_help
              return 1
          end

          set -l in $argv[1]
          if not test -f $in
              echo "vol: file not found: $in" >&2
              return 1
          end

          set -l db
          if set -q argv[2]
              set db (string replace -r '^\+' "" -- $argv[2])
              if not string match -qr '^-?[0-9]+(\.[0-9]+)?$' -- $db; or test $db -eq 0
                  echo "vol: give the change in dB, like +6 or -6" >&2
                  return 1
              end
          end

          # Measure the loudest peak, unless we're only turning it down
          if test -z "$db"; or test $db -gt 0
              set_color --dim; echo (string escape -- ffmpeg -i $in -af volumedetect -f null -); set_color normal
              set -l peak (__audio_peak $in)
              if test -z "$peak"
                  echo "vol: couldn't read the volume of $in" >&2
                  return 1
              end
              # Room left below 0 dB, keeping 1 dB spare for MP3 encoding
              set -l room (math -s1 "-1 * $peak - 1")

              if test -z "$db"
                  echo "Loudest peak: $peak dB (0 dB is the maximum)"
                  if test $room -gt 0
                      echo "It can go up about $room dB without distortion:  vol "(string escape -- $in)" +$room"
                  else
                      echo "It's already at the maximum; raising it would distort."
                  end
                  return
              end

              if test $room -le 0
                  echo "Warning: this song is already at the maximum, so +$db dB will distort the loudest parts." >&2
              else if test $db -gt $room
                  echo "Warning: +$db dB will distort the loudest parts. The most it can go up cleanly is about $room dB." >&2
              end
          end

          set -l word louder
          test $db -lt 0; and set word quieter

          set -l out (path change-extension "" -- $in)" ($word)"(path extension -- $in)
          # -c:v copy keeps any album art as it is
          set -l cmd ffmpeg -hide_banner -loglevel warning -stats -i $in -af "volume=$db""dB" -b:a 320k -c:v copy $out
          set_color --dim; echo (string escape -- $cmd); set_color normal
          $cmd
        '';
      };
    };

    xdg.configFile."fish/functions/fish_prompt.fish".text = ''
      function fish_prompt
        set -l nix_shell_info ""
        if test -n "$IN_NIX_SHELL"
          set nix_shell_info "❄️  "
        end

        set_color $fish_color_cwd
        echo -n (prompt_pwd)
        set_color normal

        echo -n -s " $nix_shell_info~> "
      end
    '';
  };
}

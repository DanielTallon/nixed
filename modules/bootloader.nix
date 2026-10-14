# /.dotfiles/modules/bootloader.nix
# Limine bootloader config.
{
  flake.modules.nixos.bootloader = { config, lib, pkgs, ... }:
  let
    # Video splash: MP4 is split into PNG frames at build time and looped by a
    # Plymouth script. Theme + script from https://github.com/Muddyblack/NixOS (MIT).
    #   ticks: frames advance every N Plymouth refreshes (50 Hz): 2 = 25 fps, 3 = 16.7 fps, 6 = 8.3 fps.
    #          More fps = smoother, but proportionally bigger initrd and more RAM at boot.
    #   size: on-screen pixel size of each frame (drawn 1:1, centered on black)
    mkVideoTheme = { name, video, ticks ? 3, size ? "1920:1080" }:
      pkgs.stdenvNoCC.mkDerivation {
        pname = "plymouth-theme-${name}";
        version = "1.0";
        src = video;
        dontUnpack = true;
        nativeBuildInputs = [ pkgs.ffmpeg pkgs.optipng ];
        buildPhase = ''
          mkdir -p frames
          ffmpeg -i ${video} -vf 'fps=50/${toString ticks},scale=${size}:flags=lanczos' \
            frames/frame-%d.png -loglevel error
          optipng -quiet -o1 frames/*.png
        '';
        installPhase = ''
          themedir=$out/share/plymouth/themes/${name}
          mkdir -p "$themedir"
          cp frames/frame-*.png "$themedir/"
          frame_count=$(ls frames | wc -l)

          sed -e "s/FRAME_COUNT_PLACEHOLDER/$frame_count/" \
              -e "s/TICKS_PER_FRAME_PLACEHOLDER/${toString ticks}/" \
              ${./assets/plymouth/plymouth-theme.script} > "$themedir/${name}.script"

          cat > "$themedir/${name}.plymouth" <<EOF
        [Plymouth Theme]
        Name=${name}
        Description=Video boot splash: ${name}
        ModuleName=script

        [script]
        ImageDir=$themedir
        ScriptFile=$themedir/${name}.script
        EOF
        '';
      };

    # Every theme name -> the package that provides it. Previews:
    #   adi1090x (~80 themes): https://github.com/adi1090x/plymouth-themes
    #   catppuccin-{latte,frappe,macchiato,mocha}: https://github.com/catppuccin/plymouth
    adi1090xNames = builtins.attrNames
      (import "${pkgs.path}/pkgs/by-name/ad/adi1090x-plymouth-themes/shas.nix");
    plymouthThemes =
      lib.genAttrs adi1090xNames (name:
        pkgs.adi1090x-plymouth-themes.override { selected_themes = [ name ]; })
      // lib.listToAttrs (map (variant: {
        name = "catppuccin-${variant}";
        value = pkgs.catppuccin-plymouth.override { inherit variant; };
      }) [ "latte" "frappe" "macchiato" "mocha" ])
      // {
        dotted = mkVideoTheme { name = "dotted"; video = ./assets/plymouth/dotted/dotted.mp4; };
      };
  in {
    options.plymouthTheme = lib.mkOption {
      type = lib.types.enum (builtins.attrNames plymouthThemes);
      default = "dotted";
      description = "Plymouth boot splash theme (any adi1090x theme, catppuccin-<variant>, or dotted). Only the selected one is built and put in the initrd.";
    };

    config = {
    boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.limine = {
      enable = true;
      validateChecksums = true;
      maxGenerations = 10;

      extraConfig = ''
        timeout: 3
        remember_last_entry: yes
        term_font_scale: 2x2
      '';

      style = {
        wallpapers = [ ./assets/boot_wallpaper.png ];
        wallpaperStyle = "centered";
      };
    };

    boot.initrd.kernelModules = lib.optionals config.hasNvidia [ "nvidia" "nvidia_modeset" "nvidia_drm" "nvidia_uvm" ];
    boot.plymouth = {
      enable = true;
      # Switch with `plymouthTheme = "rings";` (or "dotted"). To add more adi1090x
      # themes (https://github.com/adi1090x/plymouth-themes), extend plymouthThemes above.
      theme = config.plymouthTheme;
      themePackages = [ plymouthThemes.${config.plymouthTheme} ];
    };
    boot.consoleLogLevel = 0;
    boot.initrd.verbose = false;
    boot.kernelParams = [
      "quiet"
      "splash"
      "udev.log_level=3"
      "usbcore.autosuspend=-1"
    ] ++ lib.optionals config.hasNvidia [
      "nvidia_drm.modeset=1"
      "nvidia_drm.fbdev=1"
    ];

    boot.tmp.cleanOnBoot = true;
    };
  };
}

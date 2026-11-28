# /.dotfiles/modules/system/boot/bootloader.nix
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
          cat ${./assets/plymouth/plymouth-ui.script} >> "$themedir/${name}.script"

          ${mkThemeFile name "Video boot splash: ${name}"}
        '';
      };

    mkThemeFile = name: description: ''
      cat > "$themedir/${name}.plymouth" <<EOF
      [Plymouth Theme]
      Name=${name}
      Description=${description}
      ModuleName=script

      [script]
      ImageDir=$themedir
      ScriptFile=$themedir/${name}.script
      EOF
    '';

    # Logo splash with a light chasing around the snowflake: logo-chase.py writes
    # one SVG per frame (one lambda lit, a short trail behind it, the rest dimmed),
    # they're rendered to PNGs here, and the video theme's script loops them.
    #   steps: frames per lambda (6 lambdas, so 6 * steps frames per turn)
    #   ticks: Plymouth refreshes (50 Hz) per frame; one turn = 6 * steps * ticks / 50 s
    #   trail: how many lambdas behind the lit one still glow
    #   dim:   brightness of an unlit lambda, 0 to 1
    #   height: logo height in pixels, drawn 1:1 (400 is ~37% of 1080p, ~28% of 1440p)
    #   glitch: 0 = off; N = loop N turns of the chase with a glitch burst near
    #           the end of each loop (logo-glitch.py; its knobs are at the top)
    mkLogoTheme = { name, svg, steps ? 4, ticks ? 4, trail ? 2, dim ? 0.3, height ? 400, glitch ? 0 }:
      pkgs.stdenvNoCC.mkDerivation {
        pname = "plymouth-theme-${name}";
        version = "1.0";
        src = svg;
        dontUnpack = true;
        nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pillow ])) pkgs.resvg pkgs.optipng ];
        buildPhase = ''
          python3 -I ${./assets/plymouth/logo-chase.py} ${svg} frames \
            ${toString steps} ${toString trail} ${toString dim}
          for f in frames/*.svg; do
            resvg --height ${toString height} "$f" "''${f%.svg}.png"
          done
        '' + lib.optionalString (glitch > 0) ''
          python3 -I ${./assets/plymouth/logo-glitch.py} frames glitched ${toString glitch}
          rm -r frames
          mv glitched frames
        '' + ''
          optipng -quiet -o1 frames/*.png
        '';
        installPhase = ''
          themedir=$out/share/plymouth/themes/${name}
          mkdir -p "$themedir"
          cp frames/frame-*.png "$themedir/"
          frame_count=$(ls frames/*.png | wc -l)

          sed -e "s/FRAME_COUNT_PLACEHOLDER/$frame_count/" \
              -e "s/TICKS_PER_FRAME_PLACEHOLDER/${toString ticks}/" \
              ${./assets/plymouth/plymouth-theme.script} > "$themedir/${name}.script"
          cat ${./assets/plymouth/plymouth-ui.script} >> "$themedir/${name}.script"

          ${mkThemeFile name "NixOS logo boot splash"}
        '';
      };

    # Official NixOS logo (logomark + "NixOS" wordmark, white text for dark
    # backgrounds) from the NixOS branding media kit. For the side-by-side
    # layout, swap "vertical" for "horizontal" and use
    # sha256-f6HQ2J4bii/1JsfcyU/H5eyFau1nKL6m6rdLjtLXSUM= (then lower height to ~150).
    nixosLogoSvg = pkgs.fetchurl {
      url = "https://github.com/NixOS/branding/releases/download/nixos-branding-guide-v0.2.0/nixos-logo-default-gradient-white-regular-vertical-minimal.svg";
      hash = "sha256-jHlVDGJtVs+VcyXvoT6XKiuFO6TdKu5y4VFXAkHfCWs=";
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
        snowflake = mkVideoTheme { name = "snowflake"; video = ./assets/plymouth/snowflake/snowflake.mp4; };
        nixos = mkLogoTheme { name = "nixos"; svg = nixosLogoSvg; };
        nixos-glitch = mkLogoTheme { name = "nixos-glitch"; svg = nixosLogoSvg; glitch = 2; };
      };
  in {
    options.plymouthTheme = lib.mkOption {
      type = lib.types.enum (builtins.attrNames plymouthThemes);
      default = "nixos-glitch";
      description = "Plymouth boot splash theme (any adi1090x theme, catppuccin-<variant>, snowflake, nixos, or nixos-glitch). Only the selected one is built and put in the initrd.";
    };

    config = {
    boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.limine = {
      enable = true;
      validateChecksums = true;
      maxGenerations = 7;

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
      # Switch with `plymouthTheme = "rings";` (or "snowflake" / "nixos"). To add more adi1090x
      # themes (https://github.com/adi1090x/plymouth-themes), extend plymouthThemes above.
      theme = config.plymouthTheme;
      themePackages = [ plymouthThemes.${config.plymouthTheme} ];
    };
    boot.consoleLogLevel = 0;
#     boot.initrd.verbose = false;
    boot.kernelParams = [
      "quiet"
      "splash"
      "udev.log_level=3"
      "usbcore.autosuspend=-1"
    ];

    boot.tmp.cleanOnBoot = true;
    };
  };
}

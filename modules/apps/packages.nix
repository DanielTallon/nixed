# /.dotfiles/modules/apps/packages.nix
# General apps and tools that don't belong to a feature of their own. When a
# package needs config to go with it, give it its own file instead.
{
  # NOTE:`pkgs-unstable` is the nixos-unstable channel on both hosts. On the
  # unstable branch, it's the same nixpkgs as the base `pkgs`, so it changes nothing
  # there. On nixos-stable (base `pkgs` = 26.05) it's the real opt-in:
  # `pkgs-unstable.somePackage` for the occasional package you want off unstable.

  flake.modules.nixos.packages = { config, lib, pkgs, pkgs-stable, pkgs-unstable, inputs, ... }:
  let
    system = pkgs.stdenv.hostPlatform.system;
    nix-packages = inputs.nix-packages.packages.${system};
    #zen-browser = inputs.zen-browser.packages.${system}.default;
  in
  {
    nixpkgs.overlays = [
      # FIX: Upscaler fails with "vkQueueSubmit failed -4" (NVRM Xid 109, CTX
      # SWITCH TIMEOUT) on the RTX 4070 SUPER. upscayl-bin's auto tile size runs
      # GPU jobs too long to be preempted and the driver kills the context.
      # Tile size 128 runs clean. Upscaler has no tile-size option, so add -t.
      (_final: prev: {
        upscaler = prev.upscaler.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace upscaler/window.py \
              --replace-fail 'str(self.spin_scale.get_value()),' \
                             'str(self.spin_scale.get_value()), "-t", "128",'
          '';
        });
      })

      # FIX: rustdesk-flutter 1.5.0 fails with "The system library `libsodium`
      # required by crate `libsodium-sys` was not found". nixpkgs 44cddf92c4
      # ("rustPlatform.cargoSetupHook: Force system libs", 2026-10-12) sets
      # SODIUM_USE_PKG_CONFIG=1 for every Rust build, but the package doesn't
      # list libsodium. Drop this once nixpkgs adds it to buildInputs.
      # Only 1.5.0+ (unstable) needs it: on 26.05, rustdesk 1.4.5 builds fine
      # and is in cache.nixos.org, and overriding it anyway turns that download
      # into a 20+ minute local compile.
      (_final: prev: {
        rustdesk-flutter =
          if lib.versionAtLeast prev.rustdesk-flutter.version "1.5.0" then
            prev.rustdesk-flutter.overrideAttrs (old: {
              buildInputs = old.buildInputs ++ [ prev.libsodium ];
            })
          else
            prev.rustdesk-flutter;
      })
    ];

    environment.systemPackages = with pkgs; [
#   (pkgs.hello.overrideAttrs (old: {
#     postInstall = "echo 'nixed-error test: failing on purpose'; exit 1";
#   }))

      # --- General ---
      #pkgs-unstable is default for desktop
      baobab
      drawy
      ffmpeg
      fzf
      gimp
      gpu-screen-recorder-gtk
      imagemagick
      jq
      lact
      onlyoffice-desktopeditors
      pkgs-stable.inetutils #Watch Star Wars with telnet towel.blinkenlights.nl
      pass
      pdfarranger
      py7zr

      plasmusic-toolbar

      tealdeer
      tree
      usbimager #Used for flashing new ISOs on a USB
      usbutils
      wget
      xsettingsd
      xrdb
      xxd
      zenity

      # --- Music, Audio, Video ---
#       pkgs-stable.audacity
      spotdl
      deno # Required for spotdl: nix-shell -p spotdl URL
      #pkgs-stable.davinci-resolve #Vdeo Editing
      #pkgs-stable.openshot-qt #Video Editing
      parabolic
#       pkgs-stable.obs-studio
      # VLC is in vlc.nix

      # --- Utilities ---
      dysk
      keepassxc
      pv
      upscaler
      unzip

      # --- My packages (DanielTallon/nix-packages) ---
      # boot-gardener and wallpaperpicker sit with the features that use them.
      # flow-desktop is with the slow-to-build packages below.
      nix-packages.kenku-fm
      nix-packages.lgl-papercutter

      # --- System & Monitoring ---
      (pkgs.btop.override { cudaSupport = config.hasNvidia; }) #BTop (GPU stats on NVIDIA hosts)
      mission-center

      # --- Notes & Recording ---
      obsidian
    ]
    # Not in any binary cache, so a fresh install would compile them: skipped
    # in the -firstboot build and added by the first normal `nh os switch`
    # (see firstBoot in modules/hosts.nix).
    ++ lib.optionals (!config.custom.firstBoot) [
      nix-packages.flow-desktop # registers the flow:// link handler too
      rustdesk-flutter          # Remote IT; only compiles on unstable (1.5.0 overlay above)
    ];

    # --- AppImage support ---
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}

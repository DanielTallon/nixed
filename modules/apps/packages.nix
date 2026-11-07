# /.dotfiles/modules/apps/packages.nix
# General apps and tools that don't belong to a feature of their own. When a
# package needs config to go with it, give it its own file instead.
{
  # NOTE:`pkgs-unstable` is the nixos-unstable channel on both hosts. On the
  # unstable branch, it's the same nixpkgs as the base `pkgs`, so it changes nothing
  # there. On nixos-stable (base `pkgs` = 26.05) it's the real opt-in:
  # `pkgs-unstable.somePackage` for the occasional package you want off unstable.

  flake.modules.nixos.packages = { config, pkgs, pkgs-stable, pkgs-unstable, inputs, ... }:
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
      pkgs-stable.audacity
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
      nix-packages.flow-desktop       # registers the flow:// link handler too
      nix-packages.kenku-fm
      nix-packages.lgl-papercutter

      # --- System & Monitoring ---
      (pkgs.btop.override { cudaSupport = config.hasNvidia; }) #BTop (GPU stats on NVIDIA hosts)
      mission-center

      # --- Remote IT & Monitoring ---
      rustdesk-flutter

      # --- Notes & Recording ---
      obsidian
    ];

    # --- AppImage support ---
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}

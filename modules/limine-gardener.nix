# /.dotfiles/modules/limine-manual-pins.nix
{
  flake.modules.nixos.bootloader = { config, lib, pkgs, ... }:
  let
    cfg = config.custom.limineManualPins;

    mkEntry = pin: ''
      /${pin.title}
      protocol: linux
      comment: ${pin.comment}
      kernel_path: boot():/limine/manual/${pin.name}-bzImage
      cmdline: init=${pin.init} ${pin.cmdline}
      module_path: boot():/limine/manual/${pin.name}-initrd
    '';

    mkFiles = pin: {
      "limine/manual/${pin.name}-bzImage"  = builtins.storePath pin.kernelPath;
      "limine/manual/${pin.name}-initrd"   = builtins.storePath pin.initrdPath;
      "limine/manual/${pin.name}-init-ref" = builtins.storePath pin.init;
    };
  in
  {
    options.custom.limineManualPins = lib.mkOption {
      description = "Old generations manually pinned onto /boot for the Limine menu, bypassing maxGenerations.";
      default = [ ];
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name       = lib.mkOption { type = lib.types.str; description = "Short id, used in filenames — no spaces."; };
        #You make this up (short id, no spaces, e.g. gen-144)
          title      = lib.mkOption { type = lib.types.str; description = "Menu entry title."; };
        #You make this up (what shows in the Limine menu)
          comment    = lib.mkOption { type = lib.types.str; default = ""; };
        #Comment — optional, your own note

        #Run these commands to find each:

          kernelPath = lib.mkOption { type = lib.types.str; description = "Path to bzImage."; };
        #readlink -f /nix/var/nix/profiles/system-144-link/kernel
          initrdPath = lib.mkOption { type = lib.types.str; description = "Path to initrd."; };
        #readlink -f /nix/var/nix/profiles/system-144-link/initrd
          init       = lib.mkOption { type = lib.types.str; description = "Absolute /nix/store path to the generation's init."; };
        #readlink -f /nix/var/nix/profiles/system-144-link/init
          cmdline    = lib.mkOption { type = lib.types.str; description = "Remaining cmdline flags, without init=."; };
        #cat /nix/var/nix/profiles/system-144-link/kernel-params
        };
      });
    };

    config = lib.mkIf (cfg != [ ]) {
      boot.loader.limine.extraEntries = lib.concatMapStringsSep "\n" mkEntry cfg;
      boot.loader.limine.additionalFiles = lib.foldl' (acc: pin: acc // mkFiles pin) { } cfg;
    };
  };
}

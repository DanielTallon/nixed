# /.dotfiles/home-manager/proton-dpi.nix
{
  flake.modules.homeManager.protonDpi = { config, lib, pkgs, ... }:
    let
      cfg = config.custom.protonDpi;
      mkDpiScript = appid: dpi: ''
        prefix="$HOME/.local/share/Steam/steamapps/compatdata/${appid}/pfx"
        if [ -d "$prefix" ]; then
          WINEPREFIX="$prefix" ${pkgs.wine64}/bin/wine reg add \
            "HKEY_CURRENT_USER\\Control Panel\\Desktop" \
            /v LogPixels /t REG_DWORD /d ${toString dpi} /f
        fi
      '';
    in {
      options.custom.protonDpi = lib.mkOption {
        type = lib.types.attrsOf lib.types.int;
        default = { };
        description = "Per-Steam-appid Wine DPI (LogPixels) overrides, applied on home-manager activation";
      };

      config.home.activation.protonDpi = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatStringsSep "\n" (lib.mapAttrsToList mkDpiScript cfg)
      );
    };
}

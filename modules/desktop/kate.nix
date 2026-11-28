# /.dotfiles/modules/desktop/kate.nix
# Kate, with nixd as its Nix language server.
{
  flake.modules.nixos.kate = { lib, pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      kdePackages.kate
      nixd
    ];
    # Open code, config and plain-text files in Kate (Dolphin, xdg-open).
    # This is the system-wide default in /etc/xdg/mimeapps.list;
    # ~/.config/mimeapps.list wins for any type it also sets.
    # Formats with no MIME type of their own (.kdl, .jsonc, .env, .zig,
    # .vue, ...) are text/plain. HTML stays in the browser, CSV in OnlyOffice.
    xdg.mime.defaultApplications = lib.genAttrs [
      # Plain text, logs, patches
      "text/plain" "text/x-log" "text/x-patch" "text/x-readme"
      # Config and data formats
      "text/x-nix" "application/json" "application/x-json"
      "application/toml" "application/yaml" "application/x-yaml"
      "application/xml" "text/xml" "application/x-desktop"
      "text/x-dbus-service" "text/x-systemd-unit" "application/sql"
      "text/x-makefile" "text/x-cmake" "text/x-dockerfile"
      # Markup and docs
      "text/markdown" "text/x-markdown" "text/x-rst" "text/x-tex"
      "text/css" "text/x-scss" "text/x-sass" "text/x-less"
      # Shell
      "application/x-shellscript" "text/x-shellscript"
      "application/x-fishscript"
      # Programming languages
      "text/x-python" "text/x-python3" "text/javascript"
      "application/javascript" "application/x-typescript"
      "text/vnd.trolltech.linguist"  # .ts is misdetected as Qt Linguist
      "text/rust" "text/x-go" "text/x-csrc" "text/x-chdr"
      "text/x-c++src" "text/x-c++hdr" "text/x-csharp" "text/x-java"
      "text/x-kotlin" "text/x-lua" "application/x-ruby" "application/x-perl"
      "application/x-php" "text/x-haskell" "text/x-ocaml"
      "text/x-emacs-lisp" "text/x-qml"
    ] (_: "org.kde.kate.desktop");
  };

  flake.modules.homeManager.kate = { lib, pkgs, ... }: {
    # --- Kate ---
    programs.kate = {
      enable = true;
      editor.theme.name = "Dracula";
    };
    # --- Kate LSP (nixd) ---
    xdg.configFile."kate/lsp/settings.json".text = builtins.toJSON {
      servers.nix = {
        command = [ (lib.getExe pkgs.nixd) ];
        filetypes = [ "nix" ];
        rootIndicationFileNames = [ "flake.nix" "default.nix" ];
      };
    };
  };
}

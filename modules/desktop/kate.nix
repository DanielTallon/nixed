# /.dotfiles/modules/desktop/kate.nix
# Kate, with nixd as its Nix language server.
{
  flake.modules.nixos.kate = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      kdePackages.kate
      nixd
    ];
    # Open .nix files in Kate (Dolphin, xdg-open). This is the system-wide
    # default in /etc/xdg/mimeapps.list; ~/.config/mimeapps.list wins if it
    # ever sets text/x-nix too.
    xdg.mime.defaultApplications."text/x-nix" = "org.kde.kate.desktop";
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

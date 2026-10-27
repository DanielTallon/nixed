# /.dotfiles/modules/desktop/kate.nix
# Kate, with nixd as its Nix language server.
{
  flake.modules.nixos.kate = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      kdePackages.kate
      nixd
    ];
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

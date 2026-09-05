# /.dotfiles/home-manager/kate.nix
{
  flake.modules.homeManager.kate = { config, pkgs, lib, ... }: {
    # --- Kate ---
    programs.kate = {
      enable = true;
      editor.theme.name = "Dracula";
    };
    # --- Kate LSP (nixd) ---
    xdg.configFile."kate/lsp/settings.json".text = ''
      {
        "servers": {
          "nix": {
            "command": ["nixd"],
            "filetypes": ["nix"],
            "rootIndicationFileNames": ["flake.nix", "default.nix"]
          }
        }
      }
    '';
  };
}

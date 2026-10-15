# /.dotfiles/home-manager/flow-desktop.nix
{
  flake.modules.homeManager.flowDesktop = { inputs, ... }: {
    imports = [ inputs.flowtube.homeManagerModules.default ];

    # Installs Flow and registers it as the flow:// link handler.
    programs.flow-desktop.enable = true;
  };
}

# /.dotfiles/modules/chaotic.nix
{
  flake.modules.nixos.chaotic = { inputs, ... }: {
    imports = [ inputs.chaotic.nixosModules.default ];
  };
}

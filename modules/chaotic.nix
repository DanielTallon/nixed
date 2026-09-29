# /.dotfiles/modules/chaotic.nix
{
  flake.modules.nixos.chaotic = { inputs, ... }: {
    imports = [ inputs.chaotic.nixosModules.default ];
  };
}
#The option `nix.nixPath' defined in `/nix/store/v3fz0p8abrlsr6496fwg3vy5gxl8nxqs-source/modules/chaotic.nix, via option flake.modules.nixos.chaotic' has been renamed to `nix.settings.nix-path'.

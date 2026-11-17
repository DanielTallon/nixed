# /.dotfiles/modules/checks.nix
# Exposes each real host's full system build as a flake check, so
# `nix-fast-build` (run from ~/.dotfiles) evaluates and builds every host in
# parallel, starting builds as soon as each part is evaluated. Add
# `--skip-cached` to skip anything the binary caches already have.
# The *-firstboot entries and the installer are left out: they're variants of
# these two and would only repeat the same work.
# `nix flake check` builds these too, so it's slower than a plain eval now.
{ config, lib, ... }:
let
  hosts = [ "nixos" "nixos-stable" ];
in
{
  perSystem = { system, ... }: {
    checks = lib.optionalAttrs (system == "x86_64-linux") (
      lib.genAttrs hosts (h: config.flake.nixosConfigurations.${h}.config.system.build.toplevel)
    );
  };
}

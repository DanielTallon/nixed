# /.dotfiles/modules/apps/luciole.nix
# Luciole, the Noctalia devs' native Wayland file manager, installed next to
# Dolphin to try out. Dolphin stays the default file manager: nothing here
# touches MIME associations or the file-chooser portal.
#
# Luciole is young (first commit 2026-10-29, no tagged release yet), so the
# input tracks its main branch. Update it with
#   nix flake update luciole
# or pin a known-good rev in flake.nix if an update breaks something.
# There's no binary cache for it, so it compiles from source on each update.
#
# Settings: ~/.config/luciole/config.toml, or Ctrl+, in the app. Anything set
# in `programs.luciole.settings` below becomes that file (a read-only base);
# changes made in the Settings window are stored separately and still work.
# Every key: https://docs.noctalia.dev/luciole/
#
# Dropping it = delete this file and its line in hosts.nix and flake.nix.
{ inputs, ... }:
{
  # GVfs: Luciole uses it for Trash, mounted drives and sftp/smb/WebDAV
  # locations (Dolphin uses KIO instead, so it was never on here).
  flake.modules.nixos.luciole = {
    services.gvfs.enable = true;
  };

  flake.modules.homeManager.luciole = { lib, osConfig, ... }: {
    imports = [ inputs.luciole.homeModules.default ];

    programs.luciole = {
      # Left out of the installer's first build, since it compiles from source.
      enable = !osConfig.custom.firstBoot;
      settings = { };
    };
  };
}

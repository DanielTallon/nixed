# /.dotfiles/home-manager/superfile/default.nix

# superfile, configured from literal TOML files, with cd_on_quit wired into fish
{
  flake.modules.homeManager.superfile = {
    xdg.configFile."superfile/config.toml".source = ./config.toml;
    xdg.configFile."superfile/hotkeys.toml".source = ./hotkeys.toml;

    # With cd_on_quit = true, quitting writes `cd '<dir>'` to the lastdir file.
    # A child process can't change the shell's directory, so this wrapper
    # sources that file in the shell itself after superfile exits.
    programs.fish.functions.superfile = ''
      set -l lastdir "$HOME/.local/state/superfile/lastdir"
      command superfile $argv
      if test -f "$lastdir"
        source "$lastdir"
        rm -f -- "$lastdir"
      end
    '';
  };
}

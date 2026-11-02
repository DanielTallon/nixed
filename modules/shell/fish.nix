# /.dotfiles/modules/shell/fish.nix
{
  flake.modules.nixos.fish = { pkgs, pkgs-unstable, username, ... }: {
    programs.fish.enable = true;
    users.users.${username}.shell = pkgs.fish;
    environment.systemPackages = [
      pkgs.fish
      pkgs-unstable.unimatrix # the matrix rain in interactiveShellInit below
    ];

    # --- Set ~/.local/bin onto your PATH ---
    environment.localBinInPath = true;
  };

  flake.modules.homeManager.fish = { pkgs, ... }: {
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        unimatrix -f -l 'm' -a -b -c blue -s 97
        #fastfetch
        #fastfetch --config examples/25
        '';

      # Fish 4's default Ctrl+L (scrollback-push clear-screen) keeps the old
      # output in scrollback. `clear` also sends \e[3J, which wipes it too.
      functions.fish_user_key_bindings = ''
        bind ctrl-l 'clear; commandline -f repaint'
      '';
    };

    xdg.configFile."fish/functions/fish_prompt.fish".text = ''
      function fish_prompt
        set -l nix_shell_info ""
        if test -n "$IN_NIX_SHELL"
          set nix_shell_info "❄️  "
        end

        set_color $fish_color_cwd
        echo -n (prompt_pwd)
        set_color normal

        echo -n -s " $nix_shell_info~> "
      end
    '';
  };
}

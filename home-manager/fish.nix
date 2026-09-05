# /.dotfiles/home-manager/fish.nix
{
  flake.modules.homeManager.fish = { pkgs, ... }: {
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        unimatrix -f -l 'm' -a -b -c blue -s 97
        #fastfetch
        #fastfetch --config examples/25
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

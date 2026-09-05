# /.dotfiles/home-manager/git.nix
{
  flake.modules.homeManager.git = { pkgs, ... }: {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "USERNAME";
          email = "example@email.com";
        };
        init.defaultBranch = "defaultBranch";
        user.signingKey = "signingKey";
        gpg = {
          format = "ssh";
          ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        };
        commit.gpgsign = true;
      };
    };
    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        AddKeysToAgent = "yes";
        ForwardAgent = "no";
        ControlMaster = "auto";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "30m";
        IdentitiesOnly = true;
      };
      settings."github.com" = {
        User = "git";
        ControlMaster = "no";
      };
    };
    home.file.".ssh/allowed_signers".text = ''
      ssh-SSH EXAMPLE CODE
      example@email.com
    '';
    home.packages = with pkgs; [ lazygit ];
  };
}

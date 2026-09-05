# /.dotfiles/home-manager/home.nix
{
  flake.modules.homeManager.home = { config, pkgs, lib, username, ... }: {
    home.username = username;
    home.homeDirectory = lib.mkForce "/home/${username}";
    home.stateVersion = "26.11";
    home.enableNixpkgsReleaseCheck = false;

    programs.home-manager.enable = true;

    # --- Display: apply best resolution/refresh rate to all outputs on login ---
    xdg.configFile."autostart/max-resolution.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Max Resolution
      Exec=${pkgs.writeShellScript "max-resolution" ''
        sleep 2
        kscreen_doctor="${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor"
        strip_ansi="sed 's/\x1b\[[0-9;]*m//g'"

        for output in $($kscreen_doctor -o | eval $strip_ansi \
            | grep "Output:" | grep -oP "Output: \d+ \K\S+"); do
          best_mode=$($kscreen_doctor -o | eval $strip_ansi \
            | awk "/Output:.*$output/,/^        Output:/" \
            | grep -oP '\d+:\d+x\d+@[\d.]+' \
            | sort -t: -k2 -V -r \
            | head -1 \
            | grep -oP '^\d+')
          if [ -n "$best_mode" ]; then
            $kscreen_doctor \
              "output.$output.mode.$best_mode" \
              "output.$output.enable"
          fi
        done
      ''}
      Hidden=false
      X-GNOME-Autostart-enabled=true
    '';
  };
}

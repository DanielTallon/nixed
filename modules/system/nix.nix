# /.dotfiles/modules/system/nix.nix
# Nix itself: settings, binary caches, store cleanup, nh, nix-ld, the Nix
# tooling, and nix-index (home-manager half) in place of command-not-found.
{ inputs, ... }:
{
  flake.modules.nixos.nix = { pkgs, username, ... }: {
    # --- Nix Settings ---
    nix.settings = {
      warn-dirty = false;
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    # --- Store optimization ---
    # Dedupes the store once a day instead of on every build (auto-optimise-store).
    # Runs at idle priority, starts within 30 min after 11:00, and catches up if missed.
    nix.optimise = {
      automatic = true;
      dates = [ "11:00" ];
    };

    # --- Nixpkgs Configuration ---
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.permittedInsecurePackages = [
      "pnpm-10.29.2"
      "electron-40.10.5"
    ];
    nixpkgs.config.problems.handlers = {
      cups.broken = "warn"; # or "ignore" to silence entirely
    };

    # --- nh: NixOS helper with auto-clean ---
    programs.nh = {
      enable = true;
      flake = "/home/${username}/.dotfiles/";
      clean = {
        enable = true;
        extraArgs = "--keep 35";
        dates = "*-*-* 12:00:00"; # "*-*-*" means every day, "12:00:00" is noon
        #dates = "weekly"; is another option

      };
    };

    # --- Nix-ld: Run unpatched binaries that require FSH ---
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        freetype
        libX11
        libXcursor
        libXrandr
        libXinerama
        libXi
        libXxf86vm
        libGL
        pkgsi686Linux.freetype
        stdenv.cc.cc.lib
        vulkan-loader
        vulkan-validation-layers
      ];
    };

    # --- envfs: Populate /bin and /usr/bin so hardcoded shebangs/paths resolve ---
    services.envfs.enable = true;

    # nix-index (home-manager half below) answers "command not found" instead.
    programs.command-not-found.enable = false;

    environment.systemPackages = with pkgs; [
      comma
      nix-update
      nix-output-monitor
      nvd

      # --- Nix Tooling ---
      deadnix   # Find unused bindings/arguments in .nix files
      nix-init  # Generate package derivations from a URL
      nurl      # Generate fetcher calls (with hashes) from a URL
      statix    # Lint .nix files for antipatterns (`statix fix` auto-fixes)
    ];
  };

  flake.modules.homeManager.nix = {
    imports = [ inputs.nix-index-database.homeModules.nix-index ];

    programs.nix-index.enable = true;
    programs.nix-index.enableFishIntegration = true;
    programs.nix-index-database.comma.enable = true;
    programs.command-not-found.enable = false;
  };
}

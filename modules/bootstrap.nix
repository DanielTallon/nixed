# /.dotfiles/modules/bootstrap.nix
#
# One-command setup for a freshly installed NixOS machine:
#
#   nix run --extra-experimental-features 'nix-command flakes' github:DanielTallon/nixed -- <host>
#
# <host> is "nixos" (unstable) or "nixos-stable" (26.05); defaults to
# /etc/nixed-host if a nixed system already wrote one, else "nixos". Both
# hosts' hostname is "nixos", so pass nixos-stable explicitly on a fresh
# Calamares install. Either host works with or without an
# NVIDIA card: the GPU is detected and written to hosts/<host>/gpu.nix.
# Run it as your normal user (not root) AFTER Calamares has installed a
# minimal system and you've rebooted into it. It will:
#   1. clone the repo to ~/.dotfiles (refuses if that path already exists)
#   2. copy this machine's /etc/nixos/hardware-configuration.nix into it,
#      detect whether it has an NVIDIA GPU (writes hosts/<host>/gpu.nix),
#      and look for a Windows install to add to Limine's menu
#      (writes hosts/<host>/dualboot.nix)
#   3. write your username to username.nix, and tell git to leave that
#      and the files from step 2 alone, so later pulls keep them
#   4. build the system with nom (live dependency tree), then
#      `nixos-rebuild boot` — then you reboot into the real config.
#      It builds <host>-firstboot, which leaves out the few apps that
#      compile from source; the first `nh os switch` adds them.
#
# Overrides: NIXED_REPO=<git url>  NIXED_REF=<branch>  NIXED_DEST=<path>
#            NIXED_FULL=1 (build the full <host> now, compiles included)
# Also stage 2 of the no-Calamares installer (modules/installer.nix).
# See INSTALL.md for the full install walkthrough.
{
  perSystem = { pkgs, ... }: {
    apps.default = {
      type = "app";
      meta.description = "Clone these dotfiles onto a fresh NixOS install and rebuild";
      program = pkgs.lib.getExe (pkgs.writeShellApplication {
        name = "nixed-bootstrap";
        runtimeInputs = [ pkgs.git pkgs.nix-output-monitor pkgs.util-linux ];
        text = ''
          repo="''${NIXED_REPO:-https://github.com/DanielTallon/nixed.git}"
          dest="''${NIXED_DEST:-$HOME/.dotfiles}"
          ref="''${NIXED_REF:-}"
          host="''${1:-$(cat /etc/nixed-host 2>/dev/null || hostname)}"

          case "$host" in
            nixos | desktop)       host="nixos";        hwdir="desktop"      ;;
            nixos-stable | laptop) host="nixos-stable"; hwdir="nixos-stable" ;;
            *)
              echo "Unknown host '$host'. Usage: nix run github:DanielTallon/nixed -- <nixos|nixos-stable>" >&2
              exit 1
              ;;
          esac

          if [ "$(id -u)" -eq 0 ]; then
            echo "Run this as your normal user, not root (it will sudo when needed)." >&2
            exit 1
          fi

          if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
            echo "/etc/nixos/hardware-configuration.nix not found. Generate it with: sudo nixos-generate-config" >&2
            exit 1
          fi

          if [ -e "$dest" ]; then
            echo "$dest already exists. Move it aside (or set NIXED_DEST) and re-run." >&2
            exit 1
          fi

          # Ask for sudo once up front and keep it alive for the whole install
          # (the build can outlast sudo's 5-minute timeout). The loop exits
          # on its own when this script does.
          sudo -v
          while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done &

          echo "==> Cloning $repo''${ref:+ (branch $ref)} into $dest"
          git clone ''${ref:+--branch "$ref"} "$repo" "$dest"

          echo "==> Using this machine's hardware-configuration.nix for hosts/$hwdir"
          cp /etc/nixos/hardware-configuration.nix "$dest/hosts/$hwdir/hardware-configuration.nix"

          # The nixed installer (modules/installer.nix) leaves the timezone,
          # language and keyboard picked on its review screen here. Without
          # it (e.g. after Calamares) the repo's hosts/<host>/locale.nix stays.
          if [ -f /etc/nixos/locale.nix ]; then
            echo "==> Using the installer's timezone/language/keyboard (hosts/$hwdir/locale.nix)"
            cp /etc/nixos/locale.nix "$dest/hosts/$hwdir/locale.nix"
          fi

          # Look for an NVIDIA display device on the PCI bus: vendor 0x10de is
          # NVIDIA, class 0x03xxxx is a display controller (0x0300 VGA on
          # desktops, 0x0302 "3D controller" on most laptop dGPUs).
          has_nvidia=false
          for dev in /sys/bus/pci/devices/*; do
            if [ "$(cat "$dev/vendor")" = "0x10de" ] && [[ "$(cat "$dev/class")" == 0x03* ]]; then
              has_nvidia=true
            fi
          done
          echo "==> NVIDIA GPU detected: $has_nvidia (hosts/$hwdir/gpu.nix)"
          cat > "$dest/hosts/$hwdir/gpu.nix" <<EOF
          # Written by the nixed bootstrap app from this machine's PCI devices.
          # Flip it by hand if detection got it wrong. See modules/system/nvidia.nix.
          { hasNvidia = $has_nvidia; }
          EOF

          # Look for Windows: any EFI System Partition (GPT type c12a7328-...)
          # holding Microsoft's boot manager. Covers Windows on its own disk
          # and Windows sharing the Linux ESP. sudo because NixOS mounts /boot
          # with fmask/dmask 0077, and unmounted ESPs need a (read-only) mount.
          esp_guid="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
          bootmgr="EFI/Microsoft/Boot/bootmgfw.efi"
          win_partuuid=""
          while read -r dev parttype partuuid; do
            if [ "$parttype" != "$esp_guid" ] || [ -n "$win_partuuid" ]; then
              continue
            fi
            existing="$(findmnt -rno TARGET --source "$dev" | head -n1 || true)"
            if [ -n "$existing" ]; then
              if sudo test -f "$existing/$bootmgr"; then win_partuuid="$partuuid"; fi
            else
              mnt="$(mktemp -d)"
              if sudo mount -o ro "$dev" "$mnt" 2>/dev/null; then
                if sudo test -f "$mnt/$bootmgr"; then win_partuuid="$partuuid"; fi
                sudo umount "$mnt"
              fi
              rmdir "$mnt"
            fi
          done < <(lsblk -rno PATH,PARTTYPE,PARTUUID)

          if [ -n "$win_partuuid" ]; then
            echo "==> Windows found on EFI partition $win_partuuid (hosts/$hwdir/dualboot.nix)"
            cat > "$dest/hosts/$hwdir/dualboot.nix" <<EOF
          # Written by the nixed bootstrap app: Windows' boot manager was found
          # on this EFI partition. Replace with { } to drop the menu entry.
          {
            boot.loader.limine.extraEntries = '''
              /Windows
                protocol: efi
                path: uuid($win_partuuid):/$bootmgr
            ''';
          }
          EOF
          else
            echo "==> No Windows install found (hosts/$hwdir/dualboot.nix)"
            cat > "$dest/hosts/$hwdir/dualboot.nix" <<EOF
          # Written by the nixed bootstrap app: no Windows install was found.
          # To add one by hand, copy the Windows entry format from modules/bootstrap.nix.
          { }
          EOF
          fi

          me="$(id -un)"
          echo "==> Setting username to '$me' (username.nix)"
          sed -i "s/^\"youruser\"$/\"$me\"/" "$dest/username.nix"

          # These files now belong to this machine, not the repo. skip-worktree
          # tells git to leave them alone: they stay out of `git status`,
          # stashes and `git add`, and `git pull` never overwrites them.
          # Flakes still read them from disk. The update app below does the
          # same; INSTALL.md shows how to undo it to commit them to a fork.
          (cd "$dest" && git update-index --skip-worktree username.nix \
            "hosts/$hwdir/hardware-configuration.nix" "hosts/$hwdir/gpu.nix" \
            "hosts/$hwdir/dualboot.nix" "hosts/$hwdir/locale.nix")

                    # Fresh installs don't have flakes or the extra binary caches enabled
          # yet; pass both for this first build (root is a trusted user).
          # warn-dirty: the hardware config and username edits are
          # intentionally left uncommitted, so skip the "Git tree is dirty" noise.
          # The config itself adds these caches (modules/system/nix.nix),
          # but only once it's installed; this first build has to be
          # told about them. Keep this list in sync with that file:
          #   nix-community  most flake inputs' packages
          #   danieltallon  nix-packages (flow-desktop etc.)
          nixconf="experimental-features = nix-command flakes
          extra-substituters = https://nix-community.cachix.org https://danieltallon.cachix.org
          extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= danieltallon.cachix.org-1:SZgjnye3onVT+RjHyc4LgDAhTVCJTf+9MZnSXxANFVs=
          warn-dirty = false"



          # Build "<host>-firstboot": the full config minus the few packages
          # no binary cache has, so this is nearly all downloads. The first
          # `nh os switch` after reboot adds them (firstBoot in
          # modules/hosts.nix). NIXED_FULL=1 builds everything now instead.
          target="$host-firstboot"
          if [ "''${NIXED_FULL:-0}" = 1 ]; then target="$host"; fi

          # `boot`, not `switch`: the real kernel/NVIDIA setup differs from
          # Calamares' defaults, so don't activate it in the live session.
          echo "==> Building $target. This can take a while."
          sudo env NIX_CONFIG="$nixconf" PATH="$PATH" \
            nom build "$dest#nixosConfigurations.$target.config.system.build.toplevel" --no-link

          echo "==> Installing boot entry"
          sudo env NIX_CONFIG="$nixconf" nixos-rebuild boot --flake "$dest#$target"

          echo
          echo "Done. Reboot to start the real config. Use 'nh os switch' from then on."
          if [ "$target" != "$host" ]; then
            echo "Your first 'nh os switch' also builds the apps left out for now"
            echo "(Flow, RustDesk, LocalSend), which compile from source and take a while."
          fi
        '';
      });
    };

    # `nix run github:DanielTallon/nixed#update`: pull the latest repo into
    # an installed ~/.dotfiles without touching this machine's own files.
    # Runs from GitHub, so it works on installs older than this app too.
    apps.update = {
      type = "app";
      meta.description = "Pull the latest dotfiles, keeping this machine's own files";
      program = pkgs.lib.getExe (pkgs.writeShellApplication {
        name = "nixed-update";
        runtimeInputs = [ pkgs.git ];
        text = ''
          dest="''${NIXED_DEST:-$HOME/.dotfiles}"
          cd "$dest"

          case "$(cat /etc/nixed-host 2>/dev/null || echo nixos)" in
            nixos-stable) hwdir="nixos-stable" ;;
            *)            hwdir="desktop"      ;;
          esac
          # Same list the bootstrap app marks on install.
          machine_files=(username.nix "hosts/$hwdir/hardware-configuration.nix"
            "hosts/$hwdir/gpu.nix" "hosts/$hwdir/dualboot.nix" "hosts/$hwdir/locale.nix")
          protect() {
            for f in "''${machine_files[@]}"; do
              if [ -e "$f" ]; then git update-index --skip-worktree "$f"; fi
            done
          }

          # Installs from before username.nix kept the username as an
          # uncommitted edit to flake.nix, which would block the pull. The
          # edit is undone here and the name written to username.nix below.
          if [ ! -e username.nix ] && ! git diff --quiet -- flake.nix; then
            if git diff -U0 -- flake.nix | grep '^[-+][^-+]' | grep -qv 'username = '; then
              echo "flake.nix has changes besides the username. Commit or undo them first." >&2
              exit 1
            fi
            echo "==> Moving your username out of flake.nix (it now lives in username.nix)"
            git checkout -- flake.nix
          fi

          # Noctalia saves its settings file while it runs, which would put
          # it back mid-update, so pause it and start it again at the end.
          settings=modules/desktop/noctalia/settings.toml
          restart_noctalia=0
          if systemctl --user is-active --quiet noctalia.service; then
            echo "==> Pausing Noctalia"
            systemctl --user stop noctalia.service
            restart_noctalia=1
          fi
          finish() {
            if [ "$restart_noctalia" = 1 ]; then systemctl --user start noctalia.service; fi
          }
          trap finish EXIT
          if ! git diff --quiet -- "$settings"; then
            echo "==> Replacing your Noctalia settings-window changes with the repo's"
            git checkout -- "$settings"
          fi

          # A rebuild can rewrite flake.lock (a new input gets locked, or
          # `nh os switch --update`). Updating means taking the repo's
          # versions, so the local lock goes too.
          if ! git diff --quiet -- flake.lock; then
            echo "==> Replacing your local flake.lock with the repo's"
            git checkout -- flake.lock
          fi

          protect
          echo "==> Pulling"
          git pull --ff-only

          if grep -q '^"youruser"$' username.nix; then
            me="$(id -un)"
            echo "==> Setting username to '$me' (username.nix)"
            sed -i "s/^\"youruser\"$/\"$me\"/" username.nix
          fi
          protect

          echo
          echo "Up to date. Rebuild to apply it: nh os switch"
        '';
      });
    };
  };
}

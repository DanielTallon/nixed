#!/usr/bin/env bash
# Written by nixed-install. Stage 2 of the nixed install.
#
# Runs automatically on the first boot (tty1 autologin, see
# configuration.nix next to this file) while /var/lib/nixed/stage2 exists:
#   1. waits for the network
#   2. runs the nixed bootstrap app (modules/bootstrap.nix): clone the repo
#      to ~/.dotfiles, carry over hardware/locale/GPU/Windows detection,
#      build the real host, `nixos-rebuild boot`
#   3. deletes the base system's generation (so Limine can't boot back into
#      it), removes the marker and reboots into the real config
#
# To retry by hand after a failure:  bash /etc/nixos/nixed-stage2.sh
# Output is also saved to /var/log/nixed-stage2.log, with a once-a-minute
# time/memory heartbeat in /var/log/nixed-stage2-mem.log.
set -uo pipefail

host="@HOST@"
repo="@REPO@"
ref="@REF@"
marker=/var/lib/nixed/stage2
log=/var/log/nixed-stage2.log
memlog=/var/log/nixed-stage2-mem.log

# Keep a copy of everything below in $log, so a hang or failure leaves a
# record even after a power cycle. Appends, so retries add to the same file.
sudo touch "$log" "$memlog"
sudo chown "$(id -un)" "$log" "$memlog"
exec > >(tee -a "$log") 2>&1
echo "---------- stage 2 started $(date) ----------"

# Heartbeat: time + memory/swap once a minute, in its own file. If the
# machine hangs, the last line shows when, and whether RAM was running out.
(
  while kill -0 "$$" 2>/dev/null; do
    { date '+%F %T'; free -m | tail -n 2; } >>"$memlog"
    sleep 60
  done
) &

flake="git+$repo"
if [ -n "$ref" ]; then flake="$flake?ref=$ref"; fi

clear
echo "============================================================"
echo " nixed install, stage 2 of 2: building '$host'"
echo " from $flake"
echo " This takes a while. It reboots on its own when it's done."
echo "============================================================"
echo

# Wi-Fi usually needs a few seconds after boot to connect, so failed tries
# here are normal; only say something every ~10 seconds.
echo "==> Waiting for the network (Wi-Fi can take a few seconds to connect)"
online=false
start=$SECONDS
for i in $(seq 1 60); do
  if curl -fs -o /dev/null --max-time 5 https://github.com; then
    online=true
    break
  fi
  if [ $((i % 5)) -eq 0 ]; then
    echo "    still waiting ($((SECONDS - start))s)..."
  fi
  sleep 2
done
if [ "$online" = true ]; then
  echo "    online."
else
  echo "No network after 2 minutes. Connect with 'nmtui', then run:"
  echo "  bash /etc/nixos/nixed-stage2.sh"
  exit 1
fi

# A previous failed attempt leaves ~/.dotfiles behind, and the bootstrap
# refuses to clone over it. Keep it, just out of the way.
if [ -e "$HOME/.dotfiles" ]; then
  old="$HOME/.dotfiles.failed-$(date +%Y%m%d-%H%M%S)"
  echo "==> Moving the previous attempt's ~/.dotfiles to $old"
  mv "$HOME/.dotfiles" "$old"
fi

# Don't let the laptop sleep (lid closed, power key, idle) mid-build. If the
# inhibitor can't be taken for some reason, build anyway rather than fail.
inhibit=()
if systemd-inhibit --what=sleep:idle:handle-lid-switch --who=nixed --why=check true 2>/dev/null; then
  inhibit=(systemd-inhibit --what=sleep:idle:handle-lid-switch
    --who="nixed stage 2" --why="Building the real config")
else
  echo "(Couldn't block sleep; keep the lid open until this finishes.)"
fi

if NIXED_REPO="$repo" NIXED_REF="$ref" "${inhibit[@]}" \
  nix --extra-experimental-features 'nix-command flakes' run "$flake" -- "$host"; then
  # Drop this throwaway base system's boot entry. Otherwise Limine's
  # remember_last_entry (in the real config) boots straight back into it,
  # since it was the entry used last.
  echo "==> Removing the base system's boot entry"
  sudo nix-env -p /nix/var/nix/profiles/system --delete-generations old
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
  sudo rm -f "$marker"
  echo
  echo "---------- stage 2 finished $(date) ----------"
  echo "Stage 2 finished. Rebooting into the real config in 15 seconds."
  echo "(Ctrl+C to stay here; reboot later with 'sudo reboot'.)"
  sleep 15 && sudo systemctl reboot
else
  echo
  echo "---------- stage 2 failed $(date) ----------"
  echo "Stage 2 failed (see the output above, or $log). Fix the problem, then retry with:"
  echo "  bash /etc/nixos/nixed-stage2.sh"
  echo "It also runs again on its own the next time you log in on tty1."
  exit 1
fi

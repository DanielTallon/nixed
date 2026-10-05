# nixed-install: stage 1 of the nixed install. Runs on the NixOS minimal ISO.
# Packaged by modules/installer.nix, which defines these before this text:
#   LAYOUT          disko layout (installer/disk-layout.nix)
#   TEMPLATES       installer/ folder (base-configuration.nix, stage2.sh)
#   ZONEINFO        tzdata's zoneinfo dir
#   LOCALES         list of glibc UTF-8 locales, one per line
#   XKB_RULES       xkeyboard-config's base.lst
#   BASE_NIXPKGS    nixpkgs used for the small base system
#   BASE_STATE      that nixpkgs' release, used as the base's stateVersion
#   DEFAULT_REPO    git URL stage 2 clones and builds
#
# Flow: questions -> review screen -> erase disk -> small base system ->
# shut down, remove media, power on -> stage 2 (installer/stage2.sh)
# builds the real config -> reboot.

repo="${NIXED_REPO:-$DEFAULT_REPO}"
ref="${NIXED_REF:-}"
log=/tmp/nixed-install.log

if [ "$(id -u)" -ne 0 ]; then
  exec sudo --preserve-env=NIXED_REPO,NIXED_REF,NIXED_ALLOW_WINDOWS_DISK,NIXED_FONT,NIXED_COLS,NIXED_ROWS,NIXED_STAGE2_COLS "$0" "$@"
fi

# ---------- helpers ----------
# Basic 16-color codes only: the Linux console can't show 256 colors, and
# gum's old pink (212) came out as an alarming red there.
accent=10 # bright green: headings, borders, "==>" steps
sel=12    # bright blue: whatever is selected or under the cursor
text=15   # bright white: normal text
export GUM_CHOOSE_CURSOR_FOREGROUND=$sel GUM_CHOOSE_SELECTED_FOREGROUND=$sel \
  GUM_CHOOSE_HEADER_FOREGROUND=$accent GUM_CHOOSE_ITEM_FOREGROUND=$text
export GUM_INPUT_PROMPT_FOREGROUND=$accent GUM_INPUT_CURSOR_FOREGROUND=$sel \
  GUM_INPUT_HEADER_FOREGROUND=$accent GUM_INPUT_PLACEHOLDER_FOREGROUND=7
export GUM_FILTER_HEADER_FOREGROUND=$accent GUM_FILTER_PROMPT_FOREGROUND=$accent \
  GUM_FILTER_TEXT_FOREGROUND=$text GUM_FILTER_PLACEHOLDER_FOREGROUND=7 \
  GUM_FILTER_INDICATOR_FOREGROUND=$sel GUM_FILTER_CURSOR_TEXT_FOREGROUND=$sel \
  GUM_FILTER_MATCH_FOREGROUND=$sel GUM_FILTER_SELECTED_PREFIX_FOREGROUND=$sel
export GUM_CONFIRM_PROMPT_FOREGROUND=$text \
  GUM_CONFIRM_SELECTED_FOREGROUND=15 GUM_CONFIRM_SELECTED_BACKGROUND=4 \
  GUM_CONFIRM_UNSELECTED_FOREGROUND=7 GUM_CONFIRM_UNSELECTED_BACKGROUND=0

title() { gum style --foreground "$accent" --bold --margin "1 0 0 0" "$*"; }
info() { gum style --foreground "$text" "$*"; }
die() {
  gum style --foreground 9 --bold "✗ $*" >&2
  exit 1
}
step() { gum style --foreground "$accent" "==> $*"; }

# ---------- console font ----------
# The stock console font is tiny on modern screens. On a real console (not
# SSH or a terminal window), try Terminus fonts from biggest to smallest and
# keep the first that still leaves NIXED_COLS columns (default 80, so no
# screen here wraps) and 20 rows. Above 32px tall, setfont -d doubles a
# smaller font. On a 1080p screen that lands on ter-v24b doubled (24x48),
# 80x22, about twice the old size.
# NIXED_FONT=ter-v28b (or "ter-v20b -d") picks one by hand; NIXED_FONT=none
# keeps the default. Stage 2 picks a smaller one for NIXED_STAGE2_COLS
# columns (default 120), since the build output needs the width.
#
# This runs as root after the sudo re-exec above, and sudo puts us in a
# pseudo-terminal (/dev/pts/N), so `tty` can't tell whether we're on a real
# console. Instead: TERM=linux means the Linux console (sudo keeps TERM; SSH
# and terminal windows set something else), and the console showing on
# screen is /sys/class/tty/tty0/active. Fonts are set on that VT with -C and
# its size is read straight from it, not from our pseudo-terminal.
font=""
vt=""
if [ "${TERM:-}" = linux ] && [ "${NIXED_FONT:-}" != none ]; then
  vt="$(cat /sys/class/tty/tty0/active 2>/dev/null || true)"
  [[ "$vt" == tty[0-9]* ]] || vt=""
fi
set_font() { # $1 font name, $2 "-d" to double or empty
  setfont -C "/dev/$vt" ${2:+"$2"} "$CONSOLEFONTS/$1.psf.gz" 2>/dev/null
}
if [ -n "$vt" ]; then
  if [ -n "${NIXED_FONT:-}" ]; then
    read -r f d <<<"$NIXED_FONT"
    if set_font "$f" "${d:-}"; then font="$f"; fi
  else
    want_cols="${NIXED_COLS:-80}"
    want_rows="${NIXED_ROWS:-24}"
    for cand in "ter-v32b -d" "ter-v28b -d" "ter-v24b -d" "ter-v22b -d" "ter-v20b -d" \
      "ter-v18b -d" ter-v32b ter-v28b ter-v24b ter-v22b ter-v20b ter-v18b ter-v16b; do
      read -r f d <<<"$cand"
      set_font "$f" "${d:-}" || continue
      font="$f" # smallest tried so far, kept if none fit
      if read -r rows cols < <(stty -F "/dev/$vt" size) &&
        [ "$cols" -ge "$want_cols" ] && [ "$rows" -ge "$want_rows" ]; then
        break
      fi
    done
  fi
  # sudo's pseudo-terminal only learns the new size from a SIGWINCH, which
  # can lag; copy it over now so gum lays out for the size actually showing.
  if read -r rows cols < <(stty -F "/dev/$vt" size); then
    stty rows "$rows" cols "$cols" 2>/dev/null || true
  fi
fi

stage2_cols="${NIXED_STAGE2_COLS:-120}"
[[ "$stage2_cols" =~ ^[0-9]+$ ]] || stage2_cols=120

# ---------- preflight ----------
clear
gum style --border rounded --border-foreground "$accent" --padding "1 2" --margin "1 0" \
  "nixed installer" "" \
  "Stage 1: a few questions, erase one disk, install a small base system." \
  "Stage 2: after a restart, your real config builds itself and reboots."

if [ ! -d /sys/firmware/efi ]; then
  die "Booted in legacy BIOS mode. This layout needs UEFI (on a VM: set the firmware to UEFI/OVMF)."
fi

if ! curl -fsS -o /dev/null --max-time 10 https://github.com; then
  die "No internet. Connect with 'nmtui' first, then run nixed-install again."
fi

# ---------- detect timezone / language / keyboard ----------
step "Detecting location (for timezone, language and keyboard)"
geo="$(curl -fsS --max-time 10 https://ipapi.co/json/ 2>/dev/null || true)"
tz="$(jq -r '.timezone // empty' <<<"$geo" 2>/dev/null || true)"
country="$(jq -r '.country_code // empty' <<<"$geo" 2>/dev/null || true)"
languages="$(jq -r '.languages // empty' <<<"$geo" 2>/dev/null || true)"
if [ -z "$tz" ]; then
  geo="$(curl -fsS --max-time 10 https://ipinfo.io/json 2>/dev/null || true)"
  tz="$(jq -r '.timezone // empty' <<<"$geo" 2>/dev/null || true)"
  country="$(jq -r '.country // empty' <<<"$geo" 2>/dev/null || true)"
fi

valid_tz() { [ -n "$1" ] && [ -f "$ZONEINFO/$1" ]; }
valid_locale() { [ -n "$1" ] && grep -qxF "$1" "$LOCALES"; }
valid_layout() { [ -n "$1" ] && awk '/^! layout/{f=1;next} /^!/{f=0} f{print $1}' "$XKB_RULES" | grep -qxF "$1"; }
valid_variant() { # $1 layout, $2 variant ("" is always fine)
  [ -z "$2" ] && return 0
  awk '/^! variant/{f=1;next} /^!/{f=0} f{print $1, $2}' "$XKB_RULES" | grep -qxF "$2 $1:"
}

valid_tz "$tz" || tz="UTC"

# Language: first entry of ipapi's "languages" with a region, e.g. "en-US" -> en_US.UTF-8
locale=""
IFS=',' read -r -a langs <<<"$languages"
for l in "${langs[@]}"; do
  cand="${l/-/_}.UTF-8"
  if valid_locale "$cand"; then
    locale="$cand"
    break
  fi
done
valid_locale "$locale" || locale="en_US.UTF-8"

# Keyboard: countries that mostly type on a US layout get "us", the UK and
# Ireland get "gb", everyone else their country code if xkb has that layout.
cc="$(tr '[:upper:]' '[:lower:]' <<<"$country")"
case "$cc" in
  "" | us | ca | au | nz | in | ph | sg | za | my | ng | ke | hk) kb="us" ;;
  gb | ie) kb="gb" ;;
  *) kb="$cc" ;;
esac
valid_layout "$kb" || kb="us"
kbvariant=""

# ---------- questions ----------
title "Which configuration?"
host="$(gum choose --header "Host to install" \
  "nixos         (unstable: rolling release, newest NVIDIA driver)" \
  "nixos-stable  (stable: 26.05, LTS kernel, production NVIDIA driver)")"
host="${host%% *}"
[ -n "$host" ] || die "No host chosen."
info "Host: $host"

title "Your account"
while :; do
  user="$(gum input --prompt "Username: " --placeholder "lowercase, e.g. alex")"
  if [[ ! "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    info "Use lowercase letters, digits, - or _ (starting with a letter), up to 32 characters."
  elif [[ "$user" =~ ^(root|nixos|youruser)$ ]] || getent passwd "$user" >/dev/null; then
    info "'$user' is reserved, pick another."
  else
    break
  fi
done
info "Username: $user"

while :; do
  pw1="$(gum input --password --prompt "Password for $user: ")"
  pw2="$(gum input --password --prompt "Confirm password: ")"
  if [ -z "$pw1" ]; then
    info "The password can't be empty."
  elif [ "$pw1" != "$pw2" ]; then
    info "Those didn't match, try again."
  else
    break
  fi
done
pwhash="$(printf '%s' "$pw1" | mkpasswd -m yescrypt --stdin)"
unset pw1 pw2
info "Password: set"

# ---------- disk ----------
iso_disk=""
iso_src="$(findmnt -no SOURCE /iso 2>/dev/null || true)"
if [ -n "$iso_src" ]; then iso_disk="$(lsblk -no PKNAME "$iso_src" 2>/dev/null | head -n1 || true)"; fi

esp_guid="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
has_windows() { # $1 = /dev/disk; true if any partition is NTFS or holds bootmgfw.efi
  local dev parttype fstype mnt found=1
  while IFS=$'\t' read -r dev parttype fstype; do
    if [ "$fstype" = ntfs ]; then found=0; fi
    if [ "$parttype" = "$esp_guid" ]; then
      mnt="$(mktemp -d)"
      if mount -o ro "$dev" "$mnt" 2>/dev/null; then
        [ -f "$mnt/EFI/Microsoft/Boot/bootmgfw.efi" ] && found=0
        umount "$mnt"
      fi
      rmdir "$mnt"
    fi
  done < <(lsblk -Jpo PATH,PARTTYPE,FSTYPE "$1" |
    jq -r '.blockdevices[0].children[]? | [.path, (.parttype // "-"), (.fstype // "-")] | @tsv')
  return $found
}

title "Disk to erase"
choices=()
while read -r name size type; do
  [ "$type" = disk ] || continue
  case "$name" in /dev/loop* | /dev/zram* | /dev/sr* | /dev/ram*) continue ;; esac
  [ "$(basename "$name")" = "$iso_disk" ] && continue
  model="$(lsblk -dno MODEL "$name" | sed 's/ *$//')"
  gib=$((size / 1024 / 1024 / 1024))
  note=""
  if has_windows "$name"; then note="  [has Windows/NTFS]"; fi
  if [ "$gib" -lt 80 ]; then note="$note  [under 80 GB: first build may run out of space]"; fi
  choices+=("$name  ${gib} GB  ${model:-unknown model}$note")
done < <(lsblk -dbnpo NAME,SIZE,TYPE)
[ "${#choices[@]}" -gt 0 ] || die "No usable disks found."

gum style --faint "$(lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL)"
disk_line="$(gum choose --header "Everything on this disk will be erased" "${choices[@]}")"
disk="${disk_line%% *}"
[ -n "$disk" ] || die "No disk chosen."

if [[ "$disk_line" == *"[has Windows/NTFS]"* ]] && [ "${NIXED_ALLOW_WINDOWS_DISK:-}" != 1 ]; then
  die "$disk has Windows/NTFS on it. Refusing to erase it. (Override: NIXED_ALLOW_WINDOWS_DISK=1 nixed-install)"
fi

# ---------- review ----------
pick_timezone() {
  local list
  list="$( (cut -f3 "$ZONEINFO/zone1970.tab" 2>/dev/null || cut -f3 "$ZONEINFO/zone.tab") | grep -v '^#' | sort -u)"
  gum filter --header "Timezone" --placeholder "type to search, e.g. New_York" --value "" <<<"UTC
$list" || true
}
pick_locale() { gum filter --header "Language / locale" --placeholder "type to search, e.g. en_GB" <"$LOCALES" || true; }
pick_layout() {
  awk '/^! layout/{f=1;next} /^!/{f=0} f{l=$1; $1=""; printf "%-8s%s\n", l, $0}' "$XKB_RULES" |
    gum filter --header "Keyboard layout" --placeholder "type to search, e.g. German" | awk '{print $1}' || true
}
pick_variant() {
  { echo "(none)"; awk -v L="$1:" '/^! variant/{f=1;next} /^!/{f=0} f && $2==L {v=$1; $1=""; $2=""; printf "%-16s%s\n", v, $0}' "$XKB_RULES"; } |
    gum filter --header "Variant for '$1'" | awk '{print $1}' || true
}

while :; do
  title "Review"
  gum style --border rounded --padding "0 2" \
    "Host        $host" \
    "Username    $user" \
    "Timezone    $tz" \
    "Language    $locale" \
    "Keyboard    $kb${kbvariant:+ ($kbvariant)}" \
    "Disk        $disk_line" \
    "Repo        $repo${ref:+ (branch $ref)}"
  action="$(gum choose --header "Anything to change?" \
    "Looks good, continue" "Timezone" "Language" "Keyboard" "Cancel")"
  case "$action" in
    Timezone) new="$(pick_timezone)"; valid_tz "$new" && tz="$new" ;;
    Language) new="$(pick_locale)"; valid_locale "$new" && locale="$new" ;;
    Keyboard)
      new="$(pick_layout)"
      if valid_layout "$new"; then
        kb="$new"
        kbvariant="$(pick_variant "$kb")"
        [ "$kbvariant" = "(none)" ] && kbvariant=""
        valid_variant "$kb" "$kbvariant" || kbvariant=""
      fi
      ;;
    "Looks good, continue") break ;;
    *) die "Cancelled. Nothing was changed." ;;
  esac
done

title "Last chance"
typed="$(gum input --prompt "Type $(basename "$disk") to erase it and install: ")"
[ "$typed" = "$(basename "$disk")" ] || die "Didn't match. Cancelled, nothing was changed."

# ---------- install (logged from here on) ----------
exec > >(tee -a "$log") 2>&1

step "Partitioning $disk with disko (3G FAT32 /boot + btrfs /)"
umount -R /mnt 2>/dev/null || true
disko --mode destroy,format,mount --yes-wipe-all-disks --argstr device "$disk" "$LAYOUT"

step "Generating hardware-configuration.nix"
nixos-generate-config --root /mnt
# nixos-generate-config doesn't record mount options; keep the layout's btrfs ones.
sed -i 's|fsType = "btrfs";|fsType = "btrfs";\n      options = [ "compress=zstd" "noatime" ];|' \
  /mnt/etc/nixos/hardware-configuration.nix
rm -f /mnt/etc/nixos/configuration.nix

step "Writing the base system"
cat >/mnt/etc/nixos/locale.nix <<EOF
# Written by nixed-install from the choices on its review screen.
# Stage 2 copies this into the repo as hosts/<host>/locale.nix.
{
  time.timeZone = "$tz";
  i18n.defaultLocale = "$locale";
  services.xserver.xkb = {
    layout = "$kb";
    variant = "$kbvariant";
  };
  console.useXkbConfig = true;
}
EOF
sed -e "s|@HOST@|$host|g" -e "s|@USER@|$user|g" -e "s|@STATEVERSION@|$BASE_STATE|g" \
  -e "s|@FONT@|$font|g" \
  "$TEMPLATES/base-configuration.nix" >/mnt/etc/nixos/configuration.nix
sed -e "s|@HOST@|$host|g" -e "s|@REPO@|$repo|g" -e "s|@REF@|$ref|g" \
  -e "s|@FONT@|$font|g" -e "s|@STAGE2COLS@|$stage2_cols|g" \
  "$TEMPLATES/stage2.sh" >/mnt/etc/nixos/nixed-stage2.sh
chmod 644 /mnt/etc/nixos/*.nix /mnt/etc/nixos/nixed-stage2.sh

# Bring Wi-Fi connections made with nmtui over to the installed system.
if [ -d /etc/NetworkManager/system-connections ] && [ -n "$(ls -A /etc/NetworkManager/system-connections)" ]; then
  mkdir -p /mnt/etc/NetworkManager/system-connections
  cp -a /etc/NetworkManager/system-connections/. /mnt/etc/NetworkManager/system-connections/
  chmod 600 /mnt/etc/NetworkManager/system-connections/*
fi

step "Installing the base system (small; the real config builds after the reboot)"
nixos-install --root /mnt --no-root-passwd --no-channel-copy -I "nixpkgs=$BASE_NIXPKGS"

step "Setting $user's password"
install -m 600 /dev/null /mnt/root/.nixed-pw
printf '%s:%s\n' "$user" "$pwhash" >/mnt/root/.nixed-pw
nixos-enter --root /mnt -c 'chpasswd -e < /root/.nixed-pw'
rm -f /mnt/root/.nixed-pw

mkdir -p /mnt/var/lib/nixed
date >/mnt/var/lib/nixed/stage2
cp "$log" /mnt/var/log/nixed-install.log || true

sync
umount -R /mnt || true

gum style --border rounded --border-foreground "$accent" --padding "1 2" --margin "1 0" \
  "The initial NixOS install is complete." "" \
  "Press Enter to shut down. While your computer is off, remove" \
  "your ISO media, then turn your computer back on so the next" \
  "phase of the install can continue." "" \
  "(Don't remove the media before it's fully off.)"
if gum confirm --affirmative "Shut down" --negative "Stay here" "Shut down now?"; then
  systemctl poweroff
else
  info "Run 'poweroff' when you're ready, then remove the media before turning it back on."
fi

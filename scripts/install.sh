#!/usr/bin/env bash
set -euo pipefail
umask 077

# --- Usage ---

usage() {
  cat <<EOF
Usage: $0 <host>

Installs NixOS for the given flake host.

Available hosts:
  yoga        Lenovo Yoga 7 Slim Gen 8 (AMD)
  latitude    Dell E7450 (Intel)
  nix-media   Intel N100 Mini PC (media server)

Environment:
  USER_NAME       Primary user (default: dk)
  REPO_URL        Git repo to clone (default: https://github.com/Daher12/nixos-config)

Examples:
  $0 yoga
  $0 nix-media
  USER_NAME=dk $0 latitude
EOF
  exit 1
}

# --- Configuration ---

[[ $# -ge 1 ]] || usage
FLAKE_TARGET="$1"
USER_NAME="${USER_NAME:-dk}"
USER_UID="1000"
USER_GID="1000"
REPO_URL="${REPO_URL:-https://github.com/Daher12/nixos-config}"

# --- Helpers ---

die()     { echo "ERROR: $*" >&2; exit 1; }
info()    { echo "=> $*"; }
confirm() {
  read -rp "$1 [y/N] " r
  [[ "$r" =~ ^[Yy]$ ]] || die "Aborted"
}

# --- Cleanup trap ---

PW_FILE=$(mktemp)
cleanup() {
  rm -f "$PW_FILE"
}
trap cleanup EXIT

# --- Pre-flight ---

[[ $EUID -eq 0 ]] || die "Run as root"

export NIX_CONFIG="experimental-features = nix-command flakes"

deps=(nix git mountpoint curl timeout nixos-install stat mount umount)
for cmd in "${deps[@]}"; do
  command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
done

curl -fsS --connect-timeout 5 --retry 3 --retry-delay 2 https://github.com >/dev/null \
  || die "No internet or GitHub unreachable"

# --- Clone config (needed for host detection) ---

CONFIG_DIR="/tmp/nixos-config"
rm -rf "$CONFIG_DIR"
info "Cloning configuration..."
timeout 120 git clone "$REPO_URL" "$CONFIG_DIR" || die "Clone failed"

PINNED_COMMIT=$(git -C "$CONFIG_DIR" rev-parse HEAD)
info "Repo at commit: $PINNED_COMMIT"

# --- Detect host features ---

HOST_DIR="$CONFIG_DIR/hosts/$FLAKE_TARGET"
[[ -d "$HOST_DIR" ]] || die "Host '$FLAKE_TARGET' not found in hosts/"

HAS_DISKO=0
HAS_IMPERMANENCE=0
HAS_PERSIST=0

if [[ -f "$HOST_DIR/disks.nix" ]]; then
  HAS_DISKO=1
fi

if grep -rq 'impermanence.*enable.*=\s*true' "$HOST_DIR/" 2>/dev/null; then
  HAS_IMPERMANENCE=1
fi

# Detect if host config references /persist
if grep -rq '"/persist' "$HOST_DIR/" 2>/dev/null; then
  HAS_PERSIST=1
fi

info "Host:       $FLAKE_TARGET"
info "Disko:      $([ $HAS_DISKO -eq 1 ] && echo 'yes' || echo 'no')"
info "Impermanence: $([ $HAS_IMPERMANENCE -eq 1 ] && echo 'yes' || echo 'no')"

# --- Backup prompt ---

read -rp "Backup USB path (e.g. /mnt/usb, or none): " BACKUP_PATH
USE_BACKUP=1
if [[ "$BACKUP_PATH" == "none" || ! -d "$BACKUP_PATH" ]]; then
  echo "WARNING: No backup path - SSH keys and machine-id will be freshly generated."
  USE_BACKUP=0
fi

MACHINE_ID_AVAILABLE=0
if [[ "$USE_BACKUP" -eq 1 ]]; then
  if [[ -f "$BACKUP_PATH/system/machine-id" ]]; then
    MACHINE_ID_AVAILABLE=1
  else
    echo "WARNING: system/machine-id not found - new ID generated on first boot."
  fi
fi

# --- Confirmation ---

if [[ $HAS_DISKO -eq 1 ]]; then
  echo "WARNING: This will DESTROY the disks defined in the ${FLAKE_TARGET} disko config."
else
  echo "WARNING: This will install NixOS to the mounted partitions under /mnt."
fi
confirm "Proceed with install?"

# --- Disko (conditional) ---

if [[ $HAS_DISKO -eq 1 ]]; then
  info "Resolving locked disko revision from flake.lock..."
  DISKO_REV=$(nix shell nixpkgs#jq --command \
    jq -er '.nodes.disko.locked.rev' "$CONFIG_DIR/flake.lock") \
    || die "Could not extract disko rev from flake.lock"
  [[ -n "$DISKO_REV" ]] || die "disko rev is empty - check flake.lock has a disko input"
  info "Using disko rev: $DISKO_REV"

  info "Running Disko..."
  nix run "github:nix-community/disko/$DISKO_REV" -- \
    --mode destroy,format,mount \
    --flake "$CONFIG_DIR#$FLAKE_TARGET" || die "Disko failed"
else
  info "Skipping Disko (no disks.nix for $FLAKE_TARGET)"
  info "Expecting partitions already mounted under /mnt"
fi

# --- Verify mount points ---

info "Verifying mount points..."
mountpoint -q /mnt || die "/mnt is not mounted"

if [[ $HAS_DISKO -eq 1 ]]; then
  # Disko hosts mount /boot and potentially /persist, /nix
  for m in /mnt/boot; do
    mountpoint -q "$m" 2>/dev/null || echo "WARNING: $m not mounted"
  done
  if [[ $HAS_IMPERMANENCE -eq 1 ]]; then
    mountpoint -q /mnt/persist || die "/mnt/persist is not mounted (required for impermanence)"
    mountpoint -q /mnt/nix 2>/dev/null || echo "WARNING: /mnt/nix not mounted"
  fi
else
  # Non-disko: at minimum /mnt and /mnt/boot should be mounted
  mountpoint -q /mnt/boot 2>/dev/null || echo "WARNING: /mnt/boot not mounted"
fi

# --- Password hash ---

info "Setting password for ${USER_NAME}..."
echo "(input hidden - type password and press Enter)"
PW_HASH=$(nix shell nixpkgs#whois --command mkpasswd -m yescrypt) \
  || die "mkpasswd failed"
[[ "$PW_HASH" == '$y$'* ]] || die "Unexpected hash format: $PW_HASH"

printf '%s' "$PW_HASH" > "$PW_FILE"

# --- @blank template snapshot (impermanence only) ---

if [[ $HAS_IMPERMANENCE -eq 1 ]]; then
  info "Creating @blank template snapshot..."

  # Find the Btrfs device — look for /dev/mapper/cryptroot (LUKS) or fall back to
  # the device backing /mnt
  BTRFS_DEVICE=""
  if [[ -b /dev/mapper/cryptroot ]]; then
    BTRFS_DEVICE="/dev/mapper/cryptroot"
  else
    # Find the device mounted at /mnt (or the first btrfs partition)
    BTRFS_DEVICE=$(findmnt -n -o SOURCE /mnt 2>/dev/null | head -1) \
      || die "Could not determine Btrfs device for /mnt"
  fi
  info "Using Btrfs device: $BTRFS_DEVICE"

  mkdir -p /tmp/btrfs-top
  mount -t btrfs -o subvolid=5 "$BTRFS_DEVICE" /tmp/btrfs-top \
    || die "Failed to mount Btrfs top-level subvolume"

  # Populate the root skeleton inside @ itself, not through /mnt, because /mnt/nix
  # and /mnt/persist are separate mounts and would otherwise hit @nix/@persist.
  mkdir -p /tmp/btrfs-top/@/{nix,persist,boot,home,etc,tmp,var/log,var/lib/sops-nix,var/lib/sbctl}
  chmod 1777 /tmp/btrfs-top/@/tmp

  if btrfs subvolume show /tmp/btrfs-top/@blank >/dev/null 2>&1; then
    btrfs subvolume delete /tmp/btrfs-top/@blank \
      || die "Failed to remove existing @blank snapshot"
  fi

  btrfs subvolume snapshot -r /tmp/btrfs-top/@ /tmp/btrfs-top/@blank \
    || die "@blank snapshot creation failed"

  btrfs subvolume show /tmp/btrfs-top/@blank >/dev/null \
    || die "@blank snapshot verification failed"

  umount /tmp/btrfs-top || die "Failed to unmount Btrfs top-level mount"
  rmdir /tmp/btrfs-top
  info "@blank snapshot created"
else
  info "Skipping @blank snapshot (no impermanence)"
fi

# --- Persist password hash ---

if [[ $HAS_IMPERMANENCE -eq 1 ]]; then
  HASH_DEST="/mnt/persist/system/var/lib/local-passwords/${USER_NAME}.yescrypt"

  info "Writing persisted password hash..."
  install -D -m 600 -o 0 -g 0 \
    "$PW_FILE" \
    "$HASH_DEST" || die "Failed to write password hash file"

  [[ -s "$HASH_DEST" ]] \
    || die "Hash file not written - aborting before nixos-install"
  [[ "$(stat -c '%a' "$HASH_DEST")" == "600" ]] \
    || die "Hash file has wrong permissions (expected 600)"
  [[ "$(stat -c '%u:%g' "$HASH_DEST")" == "0:0" ]] \
    || die "Hash file has wrong ownership (expected root:root)"
else
  info "Skipping persist password hash (no impermanence — sops handles credentials)"
fi

# --- State Restoration (System) ---

info "Restoring system identity..."

if [[ $HAS_PERSIST -eq 1 ]]; then
  PERSIST_SYSTEM="/mnt/persist/system"
else
  PERSIST_SYSTEM="/mnt"
fi

if [[ "$USE_BACKUP" -eq 1 ]] && [[ -f "$BACKUP_PATH/ssh/ssh_host_ed25519_key" ]]; then
  info "Restoring SSH host keys..."
  mkdir -p "$PERSIST_SYSTEM/etc/ssh"
  cp -a "$BACKUP_PATH"/ssh/ssh_host_* "$PERSIST_SYSTEM/etc/ssh/"
  chmod 600 "$PERSIST_SYSTEM/etc/ssh/"*_key
  chmod 644 "$PERSIST_SYSTEM/etc/ssh/"*.pub 2>/dev/null || true
  chown -R 0:0 "$PERSIST_SYSTEM/etc/ssh"
else
  echo "WARNING: No SSH host keys - new keys generated on boot."
  echo "  Update known_hosts on machines that connect to this host."
fi

if [[ "$MACHINE_ID_AVAILABLE" -eq 1 ]]; then
  install -D -m 444 -o 0 -g 0 \
    "$BACKUP_PATH/system/machine-id" "$PERSIST_SYSTEM/etc/machine-id"
  info "Restored machine-id"
else
  info "Skipping machine-id - systemd generates on first boot"
fi

# --- State Restoration (User) ---

info "Restoring user data for $USER_NAME..."

if [[ $HAS_PERSIST -eq 1 ]]; then
  USER_HOME="/mnt/persist/home/$USER_NAME"
else
  USER_HOME="/mnt/home/$USER_NAME"
fi

mkdir -p "$USER_HOME"/{.ssh,.gnupg,nixos-config,Documents,Downloads}

if [[ "$USE_BACKUP" -eq 1 ]]; then
  [[ -d "$BACKUP_PATH/user_ssh" ]] && cp -a "$BACKUP_PATH/user_ssh/." "$USER_HOME/.ssh/"
  [[ -d "$BACKUP_PATH/gnupg"   ]] && cp -a "$BACKUP_PATH/gnupg/."    "$USER_HOME/.gnupg/"
fi

info "Cloning clean repo into user home (pinned to install commit)..."
timeout 120 git clone "$REPO_URL" "$USER_HOME/nixos-config" \
  || die "Clean repo clone into user home failed"
git -C "$USER_HOME/nixos-config" checkout --detach "$PINNED_COMMIT" \
  || die "Could not checkout pinned commit in user home clone"
rm -rf "$USER_HOME/nixos-config/.git"

info "Fixing user permissions..."
chown -R "$USER_UID:$USER_GID" "$USER_HOME"
if [[ -d "$USER_HOME/.ssh" ]]; then
  chmod 700 "$USER_HOME/.ssh"
  find "$USER_HOME/.ssh" -type f       -exec chmod 600 {} +
  find "$USER_HOME/.ssh" -name "*.pub" -exec chmod 644 {} +
fi
if [[ -d "$USER_HOME/.gnupg" ]]; then
  chmod 700 "$USER_HOME/.gnupg"
  find "$USER_HOME/.gnupg" -type d -exec chmod 700 {} +
  find "$USER_HOME/.gnupg" -type f -exec chmod 600 {} +
fi

# --- Installation ---

info "Installing NixOS..."
nixos-install --no-root-passwd --flake "$CONFIG_DIR#$FLAKE_TARGET" \
  || die "nixos-install failed"

# --- Post-install verification ---

info "Verifying root is not locked..."
ROOT_FIELD=$(nixos-enter --root /mnt -- getent shadow root 2>/dev/null | cut -d: -f2)
case "$ROOT_FIELD" in
  ""|'$'*) info "root accessible (passwordless or hashed)" ;;
  '!'*|'*') die "CRITICAL: root is locked - TTY recovery impossible" ;;
  *) die "CRITICAL: root shadow field unrecognised: $ROOT_FIELD" ;;
esac

info "Verifying ${USER_NAME} account is not locked..."
USER_FIELD=$(nixos-enter --root /mnt -- getent shadow "${USER_NAME}" 2>/dev/null | cut -d: -f2)
case "$USER_FIELD" in
  '$y$'*|'$6$'*|'$5$'*|'$2b$'*) info "${USER_NAME} account is active" ;;
  "") die "CRITICAL: ${USER_NAME} has empty password field" ;;
  '!'*|'*') die "CRITICAL: ${USER_NAME} is locked - hash file missing or invalid" ;;
  *) die "CRITICAL: ${USER_NAME} shadow field unrecognised: $USER_FIELD" ;;
esac

info "Verifying bootloader..."
[[ -d /mnt/boot/EFI ]] || die "/mnt/boot/EFI missing"
[[ -n "$(ls -A /mnt/boot/EFI 2>/dev/null)" ]] \
  || die "/mnt/boot/EFI is empty - bootloader install failed"
info "Bootloader installed"

# --- Summary ---

echo ""
echo "=============================="
echo "       INSTALL SUCCESS        "
echo "=============================="
echo "Host:   $FLAKE_TARGET"
echo "Commit: $PINNED_COMMIT"
[[ $HAS_DISKO -eq 1 ]] && echo "Disko:  $DISKO_REV"
echo ""

# --- Post-boot instructions (host-aware) ---

if [[ $HAS_IMPERMANENCE -eq 1 ]]; then
  echo "POST-BOOT: Set up Secure Boot once running:"
  echo "  1. sudo sbctl create-keys"
  echo "  2. sudo sbctl enroll-keys --microsoft"
  echo "  3. Reboot -> UEFI firmware -> enable Secure Boot"
  echo "  4. Edit hosts/$FLAKE_TARGET/default.nix: secureboot.enable = true"
  echo "  5. sudo nixos-rebuild switch --flake .#$FLAKE_TARGET"
else
  echo "POST-BOOT: Review and rebuild as needed:"
  echo "  sudo nixos-rebuild switch --flake .#$FLAKE_TARGET"
fi

confirm "Reboot now?"
reboot

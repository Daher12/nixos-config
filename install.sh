#!/usr/bin/env bash
set -euo pipefail
umask 077

# --- Configuration ---
USER_NAME="${USER_NAME:-dk}"
USER_UID="1000"
USER_GID="1000"
REPO_URL="${REPO_URL:-https://github.com/daher12/nixos-config}"
FLAKE_TARGET="${FLAKE_TARGET:-yoga}"

# --- Helpers ---
die()     { echo "ERROR: $*" >&2; exit 1; }
info()    { echo "=> $*"; }
confirm() {
    read -rp "$1 [y/N] " r
    [[ "$r" =~ ^[Yy]$ ]] || die "Aborted"
}

# --- Pre-flight ---
[[ $EUID -eq 0 ]] || die "Run as root"

export NIX_CONFIG="experimental-features = nix-command flakes"

deps=(nix git mountpoint curl timeout nixos-install openssl)
for cmd in "${deps[@]}"; do
    command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
done

curl -fsS --connect-timeout 5 --retry 3 --retry-delay 2 https://github.com >/dev/null \
    || die "No internet or GitHub unreachable"

read -rp "Backup USB path (e.g. /mnt/usb, or 'none'): " BACKUP_PATH
USE_BACKUP=1
if [[ "$BACKUP_PATH" == "none" || ! -d "$BACKUP_PATH" ]]; then
    echo "WARNING: No backup path — SSH keys and machine-id will be freshly generated."
    USE_BACKUP=0
fi

if [[ "$USE_BACKUP" -eq 1 ]]; then
    if [[ ! -f "$BACKUP_PATH/system/machine-id" ]]; then
        echo "WARNING: system/machine-id not found — new ID generated on first boot."
        MACHINE_ID_AVAILABLE=0
    else
        MACHINE_ID_AVAILABLE=1
    fi
else
    MACHINE_ID_AVAILABLE=0
fi

# Secure Boot: keys managed post-boot via sbctl on the live system.
# secureboot.enable = false during initial install — see hosts/yoga/default.nix.
SBCTL_FROM_BACKUP=0

info "Targeting Flake: $FLAKE_TARGET"
echo "WARNING: This will DESTROY the disks defined in the '$FLAKE_TARGET' disko config."
confirm "Proceed with wipe and install?"

# --- Clone config ---
CONFIG_DIR="/tmp/nixos-config"
rm -rf "$CONFIG_DIR"
info "Cloning configuration..."
timeout 120 git clone "$REPO_URL" "$CONFIG_DIR" || die "Clone failed"

# --- Partitioning ---
info "Running Disko..."
nix run "github:nix-community/disko" -- \
    --mode destroy,format,mount \
    --flake "$CONFIG_DIR#$FLAKE_TARGET" || die "Disko failed"

for m in /mnt /mnt/boot /mnt/persist /mnt/nix; do
    mountpoint -q "$m" || die "Mount point failed: $m is not a mountpoint"
done

# --- State Restoration (System) ---
info "Restoring system identity..."

if [[ "$USE_BACKUP" -eq 1 ]] && [[ -f "$BACKUP_PATH/ssh/ssh_host_ed25519_key" ]]; then
    info "Restoring SSH host keys..."
    mkdir -p /mnt/persist/system/etc/ssh
    cp -a "$BACKUP_PATH"/ssh/ssh_host_* /mnt/persist/system/etc/ssh/
    chmod 600 /mnt/persist/system/etc/ssh/*_key
    chmod 644 /mnt/persist/system/etc/ssh/*.pub 2>/dev/null || true
    chown -R 0:0 /mnt/persist/system/etc/ssh
else
    echo "WARNING: No SSH host keys — new keys generated on boot."
    echo "  Update known_hosts on machines that connect to this host."
fi

if [[ "$MACHINE_ID_AVAILABLE" -eq 1 ]]; then
    install -D -m 444 -o 0 -g 0 \
        "$BACKUP_PATH/system/machine-id" /mnt/persist/system/etc/machine-id
    info "Restored machine-id"
else
    info "Skipping machine-id — systemd generates on first boot"
fi

# --- sbctl PKI ---
# Skipped: secureboot.enable = false for initial install.
# Post-boot: sudo sbctl create-keys && sudo sbctl enroll-keys --microsoft

# --- State Restoration (User) ---
info "Restoring user data for $USER_NAME..."
USER_HOME="/mnt/persist/home/$USER_NAME"
mkdir -p "$USER_HOME"/{.ssh,.gnupg,nixos-config,Documents,Downloads}

if [[ "$USE_BACKUP" -eq 1 ]]; then
    [[ -d "$BACKUP_PATH/user_ssh" ]] && cp -a "$BACKUP_PATH/user_ssh/." "$USER_HOME/.ssh/"
    [[ -d "$BACKUP_PATH/gnupg"   ]] && cp -a "$BACKUP_PATH/gnupg/."    "$USER_HOME/.gnupg/"
fi

cp -a "$CONFIG_DIR/." "$USER_HOME/nixos-config/"

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
    || die "nixos-install failed.
  Debug: nixos-enter --root /mnt -- journalctl -b | grep -iE 'lanzaboote|error'"

# --- Post-install verification ---
info "Verifying ${USER_NAME} account is not locked..."
SHADOW=$(nixos-enter --root /mnt -- getent shadow "${USER_NAME}" 2>/dev/null || true)
[[ -n "$SHADOW" ]] || die "Could not read shadow entry for ${USER_NAME}"
if echo "$SHADOW" | grep -qE "^${USER_NAME}:!"; then
    die "CRITICAL: ${USER_NAME} is locked.
  Check users.users.dk.hashedPassword is set in hosts/yoga/default.nix"
fi
info "${USER_NAME} account is active"

info "Verifying root account..."
ROOT_HASH=$(nixos-enter --root /mnt -- getent shadow root 2>/dev/null | cut -d: -f2)
if [[ "$ROOT_HASH" == "!" || "$ROOT_HASH" == "*" ]]; then
    die "CRITICAL: root is hard-locked — TTY recovery impossible"
fi
info "root account accessible"

info "Verifying bootloader..."
[[ -d /mnt/boot/EFI ]] || die "/mnt/boot/EFI missing"
[[ -n "$(ls -A /mnt/boot/EFI 2>/dev/null)" ]] \
    || die "/mnt/boot/EFI is empty — lanzaboote install failed"
info "Bootloader installed"

echo ""
echo "=============================="
echo "       INSTALL SUCCESS        "
echo "=============================="
echo ""
echo "POST-BOOT: Set up Secure Boot once running:"
echo "  1. sudo sbctl create-keys"
echo "  2. sudo sbctl enroll-keys --microsoft"
echo "  3. Reboot -> UEFI firmware -> enable Secure Boot"
echo "  4. Edit hosts/yoga/default.nix: secureboot.enable = true"
echo "  5. sudo nixos-rebuild switch --flake .#yoga"

confirm "Reboot now?"
reboot
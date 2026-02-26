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
die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "=> $*"; }
confirm() {
    read -rp "$1 [y/N] " r
    [[ "$r" =~ ^[Yy]$ ]] || die "Aborted"
}

# --- Pre-flight ---
[[ $EUID -eq 0 ]] || die "Run as root"

deps=(nix git mountpoint curl timeout nixos-install openssl)
for cmd in "${deps[@]}"; do
    command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
done

curl -fsS --connect-timeout 5 --retry 3 --retry-delay 2 https://github.com >/dev/null \
    || die "No internet or GitHub unreachable"

read -rp "Backup USB path (e.g. /mnt/usb): " BACKUP_PATH
[[ -d "$BACKUP_PATH" ]] || die "Path not found: $BACKUP_PATH"

# Only the age key is strictly required — it decrypts all secrets at activation.
# machine-id: optional; systemd generates a new one if absent. Consequence: some
#   app state tied to machine identity (journald cursor, some licensing) is reset.
#   Restore from backup when available to preserve continuity.
# root_password_hash: removed — now managed via SOPS neededForUsers, not a file install.
# sbctl: optional — handled separately below.
req_files=(
    "sops/age.key"
)
for f in "${req_files[@]}"; do
    [[ -f "$BACKUP_PATH/$f" ]] || die "Missing required backup artifact: $f"
done

if [[ ! -f "$BACKUP_PATH/system/machine-id" ]]; then
    echo "WARNING: system/machine-id not found in backup."
    echo "  A new machine-id will be generated on first boot."
    echo "  Impact: journald cursor reset, some app state tied to machine identity lost."
    MACHINE_ID_AVAILABLE=0
else
    MACHINE_ID_AVAILABLE=1
fi

if [[ -d "$BACKUP_PATH/sbctl" ]]; then
    # Validate presence of all three Secure Boot key roles
    for key_file in keys/db/db.pem keys/KEK/KEK.pem keys/PK/PK.pem; do
        [[ -f "$BACKUP_PATH/sbctl/$key_file" ]] \
            || die "Corrupt sbctl backup: $key_file missing"
    done
    # Validate certificates are parseable — catches silent corruption before install
    for key_file in keys/db/db.pem keys/KEK/KEK.pem keys/PK/PK.pem; do
        openssl x509 -noout -in "$BACKUP_PATH/sbctl/$key_file" \
            || die "sbctl $key_file is not a valid X509 certificate"
    done
    info "sbctl backup integrity verified (PK, KEK, db)"
fi

info "Targeting Flake: $FLAKE_TARGET"
echo "WARNING: This will DESTROY the disks defined in the '$FLAKE_TARGET' disko config."
confirm "Proceed with wipe and install?"

# --- Partitioning ---
CONFIG_DIR="/tmp/nixos-config"
rm -rf "$CONFIG_DIR"

info "Cloning configuration..."
timeout 120 git clone "$REPO_URL" "$CONFIG_DIR" || die "Clone failed"

# Pin disko to the exact rev recorded in flake.lock — avoids schema drift from latest
info "Resolving disko revision from flake.lock..."
DISKO_REV="$(nix eval --raw \
  --argstr lockFile "$CONFIG_DIR/flake.lock" \
  --expr 'let lock = builtins.fromJSON (builtins.readFile (builtins.toPath lockFile));
          in lock.nodes.disko.locked.rev')" \
  || die "Failed to read disko rev from flake.lock"

info "Running Disko (rev: ${DISKO_REV:0:7})..."
nix run --extra-experimental-features "nix-command flakes" \
    "github:nix-community/disko/$DISKO_REV" -- \
    --mode destroy,format,mount \
    --flake "$CONFIG_DIR#$FLAKE_TARGET" || die "Disko failed"

# /mnt/nix is a separate btrfs subvolume (@nix), neededForBoot — verify it mounted
for m in /mnt /mnt/boot /mnt/persist /mnt/nix; do
    mountpoint -q "$m" || die "Mount point failed: $m is not a mountpoint"
done

# --- State Restoration (System) ---
info "Restoring system identity..."

if [[ -f "$BACKUP_PATH/ssh/ssh_host_ed25519_key" ]]; then
    info "Restoring SSH host keys..."
    mkdir -p /mnt/persist/system/etc/ssh
    cp -a "$BACKUP_PATH"/ssh/ssh_host_* /mnt/persist/system/etc/ssh/
    chmod 600 /mnt/persist/system/etc/ssh/*_key
    chmod 644 /mnt/persist/system/etc/ssh/*.pub 2>/dev/null || true
    chown -R 0:0 /mnt/persist/system/etc/ssh
else
    echo "WARNING: No SSH host keys found in backup. New keys will be generated on boot."
fi

# SOPS key - persist AND ephemeral for install activation
install -D -m 400 -o 0 -g 0 \
    "$BACKUP_PATH/sops/age.key" /mnt/persist/system/var/lib/sops-nix/key.txt
install -D -m 400 -o 0 -g 0 \
    "$BACKUP_PATH/sops/age.key" /mnt/var/lib/sops-nix/key.txt

# Verify SOPS Keys for Chroot Activation
[[ -f /mnt/var/lib/sops-nix/key.txt ]] \
    || die "Ephemeral SOPS key missing at /mnt/var/lib/sops-nix/key.txt — activation will fail"
[[ "$(stat -c '%a' /mnt/var/lib/sops-nix/key.txt)" == "400" ]] \
    || die "Ephemeral SOPS key has wrong permissions (expected 400)"

[[ -f /mnt/persist/system/var/lib/sops-nix/key.txt ]] \
    || die "SOPS key missing at /mnt/persist/system/var/lib/sops-nix/key.txt — neededForUsers will fail"
[[ "$(stat -c '%a' /mnt/persist/system/var/lib/sops-nix/key.txt)" == "400" ]] \
    || die "SOPS key has wrong permissions (expected 400)"

# machine-id: restore if available, otherwise systemd generates one on first boot
if [[ "$MACHINE_ID_AVAILABLE" -eq 1 ]]; then
    install -D -m 444 -o 0 -g 0 \
        "$BACKUP_PATH/system/machine-id" /mnt/persist/system/etc/machine-id
    info "Restored machine-id from backup"
else
    info "Skipping machine-id restore — systemd will generate on first boot"
fi

# root_password_hash: managed via SOPS neededForUsers — not installed as a file.
# If SOPS decryption fails on first boot, root is locked ("!").
# Recover via SSH keys or dk wheel account.

# sbctl keys - persist AND ephemeral for lanzaboote install
if [[ -d "$BACKUP_PATH/sbctl" ]]; then
    mkdir -p /mnt/persist/system/var/lib/sbctl
    cp -a "$BACKUP_PATH/sbctl/." /mnt/persist/system/var/lib/sbctl/
    chown -R 0:0 /mnt/persist/system/var/lib/sbctl
    chmod 700 /mnt/persist/system/var/lib/sbctl

    mkdir -p /mnt/var/lib/sbctl
    cp -a "$BACKUP_PATH/sbctl/." /mnt/var/lib/sbctl/
    chown -R 0:0 /mnt/var/lib/sbctl
    chmod 700 /mnt/var/lib/sbctl
fi

# --- State Restoration (User) ---
info "Restoring user data for $USER_NAME..."
# HM impermanence (home.persistence."/persist") appends home.homeDirectory automatically:
# home.persistence."/persist" → bind sources at /persist/home/$USER
USER_HOME="/mnt/persist/home/$USER_NAME"

mkdir -p "$USER_HOME"/{.ssh,.gnupg,nixos-config,Documents,Downloads}

if [[ -d "$BACKUP_PATH/user_ssh" ]]; then
    cp -a "$BACKUP_PATH/user_ssh/." "$USER_HOME/.ssh/"
fi

if [[ -d "$BACKUP_PATH/gnupg" ]]; then
    cp -a "$BACKUP_PATH/gnupg/." "$USER_HOME/.gnupg/"
fi

cp -a "$CONFIG_DIR/." "$USER_HOME/nixos-config/"

# User age key — required at first login for user-level sops CLI operations
mkdir -p "$USER_HOME/.config/sops/age"
install -D -m 600 -o "$USER_UID" -g "$USER_GID" \
    "$BACKUP_PATH/sops/age.key" "$USER_HOME/.config/sops/age/keys.txt"

info "Fixing user permissions..."
chown -R "$USER_UID:$USER_GID" "$USER_HOME"

if [[ -d "$USER_HOME/.ssh" ]]; then
    chmod 700 "$USER_HOME/.ssh"
    find "$USER_HOME/.ssh" -type f -exec chmod 600 {} + 2>/dev/null || true
    find "$USER_HOME/.ssh" -name "*.pub" -exec chmod 644 {} + 2>/dev/null || true
fi

if [[ -d "$USER_HOME/.gnupg" ]]; then
    chmod 700 "$USER_HOME/.gnupg"
    find "$USER_HOME/.gnupg" -type d -exec chmod 700 {} + 2>/dev/null || true
    find "$USER_HOME/.gnupg" -type f -exec chmod 600 {} + 2>/dev/null || true
fi

# --- Installation ---
info "Installing NixOS..."
# --no-root-passwd: mutableUsers=false manages root declaratively; interactive prompt
# would be overwritten by activation anyway and causes non-interactive install to hang.
nixos-install --no-root-passwd --flake "$CONFIG_DIR#$FLAKE_TARGET" || die "Install failed"

# --- Verify shadow post-install ---
info "Verifying ${USER_NAME} account is not locked..."
SHADOW=$(nixos-enter --root /mnt -- getent shadow "${USER_NAME}" 2>/dev/null || true)
if echo "$SHADOW" | grep -qE "^${USER_NAME}:!"; then
    die "CRITICAL: ${USER_NAME} is locked. SOPS failed during activation.
  Debug: nixos-enter --root /mnt -- journalctl | grep -i sops"
fi
info "✓ ${USER_NAME} account is active"

# Verify root is not locked (SOPS neededForUsers should have set the password)
info "Verifying root account has a password set..."
ROOT_SHADOW=$(nixos-enter --root /mnt -- getent shadow root 2>/dev/null || true)
ROOT_HASH=$(echo "$ROOT_SHADOW" | cut -d: -f2)
if [[ "$ROOT_HASH" == "!" || "$ROOT_HASH" == "*" || -z "$ROOT_HASH" ]]; then
    echo "WARNING: root account is locked or has no password."
    echo "  This is expected only if SOPS decryption succeeded but root_password_hash"
    echo "  is intentionally absent from secrets/hosts/${FLAKE_TARGET}.yaml."
    echo "  If unintentional: nixos-enter --root /mnt -- journalctl | grep -i sops"
fi

# --- Verification ---
info "Verifying bootloader..."
[[ -d /mnt/boot/EFI ]] || die "/mnt/boot/EFI missing"
if [[ -z "$(ls -A /mnt/boot/EFI 2>/dev/null)" ]]; then
    die "Build success but /mnt/boot/EFI is empty. Bootloader install failed?"
fi

echo "SUCCESS"
confirm "Reboot now?"
reboot

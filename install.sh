#!/usr/bin/env bash
set -euo pipefail
umask 077 # Security: Default to private file creation

# --- Configuration ---
USER_NAME="${USER_NAME:-dk}"
USER_UID="1000" # Hardcoded for safety/speed in single-user config
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

# 1. Dependency Check
deps=(nix git mountpoint curl timeout nixos-install)
for cmd in "${deps[@]}"; do
    command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
done

# 2. Connectivity
curl -fsS --connect-timeout 5 --retry 3 --retry-delay 2 https://github.com >/dev/null \
    || die "No internet or GitHub unreachable"

# 3. Backup Validation
read -rp "Backup USB path (e.g. /mnt/usb): " BACKUP_PATH
[[ -d "$BACKUP_PATH" ]] || die "Path not found: $BACKUP_PATH"

# Restore Strict Validation (Fail Early)
req_files=(
    "ssh/ssh_host_ed25519_key"
    "ssh/ssh_host_rsa_key"
    "sops/age.key"
    "system/machine-id"
)
for f in "${req_files[@]}"; do
    [[ -f "$BACKUP_PATH/$f" ]] || die "Missing required backup artifact: $f"
done

# Optional: Validate sbctl if present
if [[ -d "$BACKUP_PATH/sbctl" ]]; then
    [[ -f "$BACKUP_PATH/sbctl/keys/db/db.pem" ]] || die "Corrupt sbctl backup: keys/db/db.pem missing"
fi

# 4. Safety Prompt
info "Targeting Flake: $FLAKE_TARGET"
echo "WARNING: This will DESTROY the disks defined in the '$FLAKE_TARGET' disko config."
confirm "Proceed with wipe and install?"

# --- Partitioning ---
CONFIG_DIR="/tmp/nixos-config"
rm -rf "$CONFIG_DIR"

info "Cloning configuration..."
timeout 120 git clone "$REPO_URL" "$CONFIG_DIR" || die "Clone failed"

info "Running Disko..."
nix run --extra-experimental-features "nix-command flakes" \
    github:nix-community/disko -- \
    --mode destroy,format,mount \
    --flake "$CONFIG_DIR#$FLAKE_TARGET" || die "Disko failed"

# Verify Mounts (Added)
for m in /mnt /mnt/boot /mnt/persist; do
    mountpoint -q "$m" || die "Mount point failed: $m is not a mountpoint"
done

# --- State Restoration (System) ---
info "Restoring system identity..."

mkdir -p /mnt/persist/system/etc/ssh
cp -a "$BACKUP_PATH"/ssh/ssh_host_* /mnt/persist/system/etc/ssh/
chmod 600 /mnt/persist/system/etc/ssh/*_key
chmod 644 /mnt/persist/system/etc/ssh/*.pub 2>/dev/null || true
chown -R 0:0 /mnt/persist/system/etc/ssh

install -D -m 400 -o 0 -g 0 \
    "$BACKUP_PATH/sops/age.key" /mnt/persist/system/var/lib/sops-nix/key.txt

install -D -m 444 -o 0 -g 0 \
    "$BACKUP_PATH/system/machine-id" /mnt/persist/system/etc/machine-id

if [[ -d "$BACKUP_PATH/sbctl" ]]; then
    mkdir -p /mnt/persist/system/var/lib/sbctl
    cp -a "$BACKUP_PATH/sbctl/." /mnt/persist/system/var/lib/sbctl/
    chown -R 0:0 /mnt/persist/system/var/lib/sbctl
    chmod 700 /mnt/persist/system/var/lib/sbctl
fi

# --- State Restoration (User) ---
info "Restoring user data for $USER_NAME..."
USER_HOME="/mnt/persist/home/$USER_NAME"

mkdir -p "$USER_HOME"/{.ssh,.gnupg,nixos-config,Documents,Downloads}

if [[ -d "$BACKUP_PATH/user_ssh" ]]; then
    cp -a "$BACKUP_PATH/user_ssh/." "$USER_HOME/.ssh/"
fi

if [[ -d "$BACKUP_PATH/gnupg" ]]; then
    cp -a "$BACKUP_PATH/gnupg/." "$USER_HOME/.gnupg/"
fi

cp -a "$CONFIG_DIR/." "$USER_HOME/nixos-config/"

info "Fixing user permissions..."
chown -R "$USER_UID:$USER_GID" "$USER_HOME"

# Recursive Security Fixes (SSH)
[[ -d "$USER_HOME/.ssh" ]] && chmod 700 "$USER_HOME/.ssh"
find "$USER_HOME/.ssh" -type f -exec chmod 600 {} + 2>/dev/null || true
find "$USER_HOME/.ssh" -name "*.pub" -exec chmod 644 {} + 2>/dev/null || true

# Recursive Security Fixes (GPG - Added)
if [[ -d "$USER_HOME/.gnupg" ]]; then
    chmod 700 "$USER_HOME/.gnupg"
    find "$USER_HOME/.gnupg" -type d -exec chmod 700 {} + 2>/dev/null || true
    find "$USER_HOME/.gnupg" -type f -exec chmod 600 {} + 2>/dev/null || true
fi

# --- Installation ---
info "Installing NixOS..."
nixos-install --flake "$CONFIG_DIR#$FLAKE_TARGET" || die "Install failed"

# --- Verification ---
info "Verifying bootloader..."
[[ -d /mnt/boot/EFI ]] || die "/mnt/boot/EFI missing"
if [[ -z "$(ls -A /mnt/boot/EFI 2>/dev/null)" ]]; then
    die "Build success but /mnt/boot/EFI is empty. Bootloader install failed?"
fi

echo "SUCCESS"
confirm "Reboot now?"
reboot

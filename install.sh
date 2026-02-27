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

# NIX_CONFIG is inherited by all nix subprocesses including nixos-install.
# Avoids needing --extra-experimental-features on every call and requires
# no writes to /etc/nix/nix.conf (read-only on NixOS ISOs).
export NIX_CONFIG="experimental-features = nix-command flakes"

deps=(nix git mountpoint curl timeout nixos-install openssl)
for cmd in "${deps[@]}"; do
    command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
done

curl -fsS --connect-timeout 5 --retry 3 --retry-delay 2 https://github.com >/dev/null \
    || die "No internet or GitHub unreachable"

read -rp "Backup USB path (e.g. /mnt/usb): " BACKUP_PATH
[[ -d "$BACKUP_PATH" ]] || die "Path not found: $BACKUP_PATH"

# Only the age key is strictly required — it decrypts all secrets at activation.
req_files=("sops/age.key")
for f in "${req_files[@]}"; do
    [[ -f "$BACKUP_PATH/$f" ]] || die "Missing required backup artifact: $f"
done

# machine-id: optional; systemd generates a new one if absent.
# Consequence: journald cursor reset, some app state tied to machine identity is reset.
if [[ ! -f "$BACKUP_PATH/system/machine-id" ]]; then
    echo "WARNING: system/machine-id not found in backup."
    echo "  A new machine-id will be generated on first boot."
    echo "  Impact: journald cursor reset, some app state tied to machine identity lost."
    MACHINE_ID_AVAILABLE=0
else
    MACHINE_ID_AVAILABLE=1
fi

# --- Validate sbctl backup if present ---
SBCTL_FROM_BACKUP=0
if [[ -d "$BACKUP_PATH/sbctl" ]]; then
    # Validate presence of all three Secure Boot key roles
    for key_file in keys/db/db.pem keys/KEK/KEK.pem keys/PK/PK.pem; do
        [[ -f "$BACKUP_PATH/sbctl/$key_file" ]] \
            || die "Corrupt sbctl backup: $key_file missing"
    done
    # Validate certificates are parseable — catches silent corruption before install
    for key_file in keys/db/db.pem keys/KEK/KEK.pem keys/PK/PK.pem; do
        openssl x509 -noout -in "$BACKUP_PATH/sbctl/$key_file" 2>/dev/null \
            || die "sbctl $key_file is not a valid X509 certificate"
    done
    info "sbctl backup integrity verified (PK, KEK, db)"
    SBCTL_FROM_BACKUP=1
else
    echo "WARNING: No sbctl backup found."
    echo "  Fresh Secure Boot PKI will be generated."
    echo "  CONSEQUENCE: Previously enrolled keys are lost."
    echo "  POST-BOOT REQUIRED: sudo sbctl enroll-keys --microsoft"
    echo "  Then: reboot → UEFI firmware → enable Secure Boot"
fi

# --- Verify SOPS key can actually decrypt the target host secrets ---
# This catches the 'wrong key' scenario that passes file-existence checks
# but fails silently at activation, leaving dk locked.
info "Verifying SOPS age key decrypts ${FLAKE_TARGET} secrets..."
CONFIG_DIR="/tmp/nixos-config"
rm -rf "$CONFIG_DIR"

info "Cloning configuration (needed for SOPS pre-flight check)..."
timeout 120 git clone "$REPO_URL" "$CONFIG_DIR" || die "Clone failed"

SOPS_SECRETS_FILE="$CONFIG_DIR/secrets/hosts/${FLAKE_TARGET}.yaml"
[[ -f "$SOPS_SECRETS_FILE" ]] \
    || die "Secrets file not found: $SOPS_SECRETS_FILE — wrong FLAKE_TARGET?"

SOPS_AGE_KEY_FILE="$BACKUP_PATH/sops/age.key" \
    nix shell nixpkgs#sops --command \
    sops --decrypt "$SOPS_SECRETS_FILE" > /dev/null 2>&1 \
    || die "SOPS decryption failed — age key does not decrypt ${FLAKE_TARGET}.yaml.
  Verify the correct key is at: $BACKUP_PATH/sops/age.key
  Expected recipient: check .sops.yaml for host_${FLAKE_TARGET} entry"
info "✓ SOPS key verified against ${FLAKE_TARGET}.yaml"

info "Targeting Flake: $FLAKE_TARGET"
echo "WARNING: This will DESTROY the disks defined in the '$FLAKE_TARGET' disko config."
confirm "Proceed with wipe and install?"

# --- Partitioning ---
info "Running Disko..."
nix run "github:nix-community/disko" -- \
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
    echo "WARNING: No SSH host keys in backup. New keys will be generated on boot."
    echo "  Impact: Update known_hosts on all machines that connect to this host."
fi

# SOPS key — persist AND ephemeral:
#   persist path: sops.age.keyFile = "/persist/system/var/lib/sops-nix/key.txt"
#                 survives root wipes via impermanence bind
#   ephemeral path: /mnt/var/lib/sops-nix/key.txt
#                   required for nixos-install chroot activation (no bind mounts)
install -D -m 400 -o 0 -g 0 \
    "$BACKUP_PATH/sops/age.key" /mnt/persist/system/var/lib/sops-nix/key.txt
install -D -m 400 -o 0 -g 0 \
    "$BACKUP_PATH/sops/age.key" /mnt/var/lib/sops-nix/key.txt

# Verify both placements before proceeding
[[ -f /mnt/var/lib/sops-nix/key.txt ]] \
    || die "Ephemeral SOPS key missing at /mnt/var/lib/sops-nix/key.txt — activation will fail"
[[ "$(stat -c '%a' /mnt/var/lib/sops-nix/key.txt)" == "400" ]] \
    || die "Ephemeral SOPS key has wrong permissions (expected 400)"
[[ -f /mnt/persist/system/var/lib/sops-nix/key.txt ]] \
    || die "SOPS key missing at /mnt/persist/system/var/lib/sops-nix/key.txt — neededForUsers will fail"
[[ "$(stat -c '%a' /mnt/persist/system/var/lib/sops-nix/key.txt)" == "400" ]] \
    || die "SOPS key has wrong permissions (expected 400)"

# machine-id
if [[ "$MACHINE_ID_AVAILABLE" -eq 1 ]]; then
    install -D -m 444 -o 0 -g 0 \
        "$BACKUP_PATH/system/machine-id" /mnt/persist/system/etc/machine-id
    info "Restored machine-id from backup"
else
    info "Skipping machine-id restore — systemd will generate on first boot"
fi

# sbctl PKI — persist AND ephemeral for lanzaboote activation during nixos-install
if [[ "$SBCTL_FROM_BACKUP" -eq 1 ]]; then
    info "Restoring sbctl PKI from backup..."
    mkdir -p /mnt/persist/system/var/lib/sbctl
    cp -a "$BACKUP_PATH/sbctl/." /mnt/persist/system/var/lib/sbctl/
    chown -R 0:0 /mnt/persist/system/var/lib/sbctl
    chmod 700 /mnt/persist/system/var/lib/sbctl

    mkdir -p /mnt/var/lib/sbctl
    cp -a "$BACKUP_PATH/sbctl/." /mnt/var/lib/sbctl/
    chown -R 0:0 /mnt/var/lib/sbctl
    chmod 700 /mnt/var/lib/sbctl
    info "sbctl PKI restored from backup"
else
    # Generate fresh PKI. Keys are NOT enrolled in UEFI yet.
    # Secure Boot remains disabled until: sbctl enroll-keys + UEFI toggle post-boot.
    info "Generating fresh sbctl Secure Boot PKI..."
    SBCTL_DB="/mnt/var/lib/sbctl"
    mkdir -p "$SBCTL_DB"

    # VERIFY: --database-path flag available in sbctl version pinned in nixpkgs/nixos-25.11
    # Fallback if flag unavailable: export SBCTL_DB and use default detection
    nix shell nixpkgs#sbctl --command \
        sbctl create-keys --database-path "$SBCTL_DB" \
        || die "sbctl create-keys failed"

    chown -R 0:0 "$SBCTL_DB"
    chmod 700 "$SBCTL_DB"

    # Persist for post-boot impermanence bind and key survival across wipes
    mkdir -p /mnt/persist/system/var/lib/sbctl
    cp -a "$SBCTL_DB/." /mnt/persist/system/var/lib/sbctl/
    chown -R 0:0 /mnt/persist/system/var/lib/sbctl
    chmod 700 /mnt/persist/system/var/lib/sbctl
    info "Fresh sbctl PKI generated (NOT yet enrolled in UEFI)"
fi

# Validate PKI is populated regardless of source before handing to nixos-install
for key_file in /mnt/var/lib/sbctl/keys/db/db.pem \
                /mnt/var/lib/sbctl/keys/KEK/KEK.pem \
                /mnt/var/lib/sbctl/keys/PK/PK.pem; do
    [[ -f "$key_file" ]] || die "sbctl PKI incomplete: $key_file missing after setup"
done
info "✓ sbctl PKI validated at /mnt/var/lib/sbctl"

# --- State Restoration (User) ---
info "Restoring user data for $USER_NAME..."
# home.persistence."/persist" appends homeDirectory automatically:
# → bind sources at /persist/home/$USER_NAME
USER_HOME="/mnt/persist/home/$USER_NAME"

mkdir -p "$USER_HOME"/{.ssh,.gnupg,nixos-config,Documents,Downloads}

if [[ -d "$BACKUP_PATH/user_ssh" ]]; then
    cp -a "$BACKUP_PATH/user_ssh/." "$USER_HOME/.ssh/"
fi

if [[ -d "$BACKUP_PATH/gnupg" ]]; then
    cp -a "$BACKUP_PATH/gnupg/." "$USER_HOME/.gnupg/"
fi

cp -a "$CONFIG_DIR/." "$USER_HOME/nixos-config/"

# User age key — required for user-level sops CLI operations post-boot
# Persisted via home.persistence file entry: .config/sops/age/keys.txt
mkdir -p "$USER_HOME/.config/sops/age"
install -m 600 \
    "$BACKUP_PATH/sops/age.key" "$USER_HOME/.config/sops/age/keys.txt"

info "Fixing user permissions..."
chown -R "$USER_UID:$USER_GID" "$USER_HOME"

if [[ -d "$USER_HOME/.ssh" ]]; then
    chmod 700 "$USER_HOME/.ssh"
    find "$USER_HOME/.ssh" -type f   -exec chmod 600 {} +
    find "$USER_HOME/.ssh" -name "*.pub" -exec chmod 644 {} +
fi

if [[ -d "$USER_HOME/.gnupg" ]]; then
    chmod 700 "$USER_HOME/.gnupg"
    find "$USER_HOME/.gnupg" -type d -exec chmod 700 {} +
    find "$USER_HOME/.gnupg" -type f -exec chmod 600 {} +
fi

# --- Installation ---
info "Installing NixOS..."
# --no-root-passwd: mutableUsers=false manages root declaratively via SOPS.
# Interactive prompt would be overwritten by activation and hangs non-interactive installs.
nixos-install --no-root-passwd --flake "$CONFIG_DIR#$FLAKE_TARGET" \
    || die "nixos-install failed.
  Debug: nixos-enter --root /mnt -- journalctl -b | grep -iE 'sops|lanzaboote|error'"

# --- Post-install shadow verification ---
# Chroot activation ran with the ephemeral SOPS key at /mnt/var/lib/sops-nix/key.txt.
# If SOPS decrypted successfully, dk's hashedPasswordFile resolved and shadow is set.
# If shadow shows '!' the key was wrong or activation failed silently.
info "Verifying ${USER_NAME} account is not locked..."
SHADOW=$(nixos-enter --root /mnt -- getent shadow "${USER_NAME}" 2>/dev/null || true)
if [[ -z "$SHADOW" ]]; then
    die "CRITICAL: Could not read shadow entry for ${USER_NAME}"
fi
if echo "$SHADOW" | grep -qE "^${USER_NAME}:!"; then
    die "CRITICAL: ${USER_NAME} is locked. SOPS failed during chroot activation.
  This should not happen — SOPS key was pre-verified above.
  Debug: nixos-enter --root /mnt -- journalctl | grep -iE 'sops|error'"
fi
info "✓ ${USER_NAME} account is active"

# Verify root has a password or empty-password (never '!' locked)
# root.hashedPassword = \"\" is the intentional TTY recovery fallback.
info "Verifying root account state..."
ROOT_SHADOW=$(nixos-enter --root /mnt -- getent shadow root 2>/dev/null || true)
ROOT_HASH=$(echo "$ROOT_SHADOW" | cut -d: -f2)
if [[ "$ROOT_HASH" == "!" || "$ROOT_HASH" == "*" ]]; then
    die "CRITICAL: root is hard-locked (hash='$ROOT_HASH').
  TTY recovery impossible. Check modules/core/users.nix root config."
fi
info "✓ root account accessible (hash: ${ROOT_HASH:0:6}... — empty=passwordless is expected)"

# --- Bootloader verification ---
info "Verifying bootloader..."
[[ -d /mnt/boot/EFI ]] || die "/mnt/boot/EFI missing"
[[ -n "$(ls -A /mnt/boot/EFI 2>/dev/null)" ]] \
    || die "/mnt/boot/EFI is empty — lanzaboote install failed?"

# lanzaboote writes signed images to /boot/EFI/Linux
if [[ -z "$(ls /mnt/boot/EFI/Linux/*.efi 2>/dev/null)" ]]; then
    echo "WARNING: No signed EFI images in /mnt/boot/EFI/Linux."
    echo "  lanzaboote may not have signed images yet."
    echo "  If Secure Boot was just enrolled this is expected on first generation."
fi
info "✓ Bootloader installed"

echo ""
echo "=============================="
echo "         INSTALL SUCCESS      "
echo "=============================="
if [[ "$SBCTL_FROM_BACKUP" -eq 0 ]]; then
    echo ""
    echo "POST-BOOT REQUIRED (fresh sbctl PKI):"
    echo "  1. Boot normally (Secure Boot DISABLED in UEFI)"
    echo "  2. sudo sbctl enroll-keys --microsoft"
    echo "  3. Reboot → enter UEFI firmware → enable Secure Boot"
    echo "  4. sudo sbctl verify  (all images should show 'signed')"
fi
if [[ "$MACHINE_ID_AVAILABLE" -eq 0 ]]; then
    echo ""
    echo "NOTE: New machine-id generated. journald cursor reset."
fi

confirm "Reboot now?"
reboot
#!/usr/bin/env bash
set -euo pipefail
umask 077

# --- Configuration ---
USER_NAME="${USER_NAME:-dk}"
USER_UID="1000"
USER_GID="1000"
REPO_URL="${REPO_URL:-https://github.com/Daher12/nixos-config}"
FLAKE_TARGET="${FLAKE_TARGET:-yoga}"

# --- Helpers ---
die()     { echo "ERROR: $*" >&2; exit 1; }
info()    { echo "=> $*"; }
confirm() {
    read -rp "$1 [y/N] " r
    [[ "$r" =~ ^[Yy]$ ]] || die "Aborted"
}

# --- Cleanup trap ---
# Runs on any exit (success, failure, signal).
# Ensures password material is never left on disk.
PW_FILE=$(mktemp)
PY_FILE=$(mktemp)
cleanup() {
    rm -f "$PW_FILE" "$PY_FILE"
}
trap cleanup EXIT

# --- Pre-flight ---
[[ $EUID -eq 0 ]] || die "Run as root"

export NIX_CONFIG="experimental-features = nix-command flakes"

# Only check tools present on the NixOS ISO.
# python3, mkpasswd (whois pkg) pulled via nix shell when needed.
deps=(nix git mountpoint curl timeout nixos-install)
for cmd in "${deps[@]}"; do
    command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
done

curl -fsS --connect-timeout 5 --retry 3 --retry-delay 2 https://github.com >/dev/null \
    || die "No internet or GitHub unreachable"

read -rp "Backup USB path (e.g. /mnt/usb, or none): " BACKUP_PATH
USE_BACKUP=1
if [[ "$BACKUP_PATH" == "none" || ! -d "$BACKUP_PATH" ]]; then
    echo "WARNING: No backup path -- SSH keys and machine-id will be freshly generated."
    USE_BACKUP=0
fi

MACHINE_ID_AVAILABLE=0
if [[ "$USE_BACKUP" -eq 1 ]]; then
    if [[ -f "$BACKUP_PATH/system/machine-id" ]]; then
        MACHINE_ID_AVAILABLE=1
    else
        echo "WARNING: system/machine-id not found -- new ID generated on first boot."
    fi
fi

info "Targeting Flake: $FLAKE_TARGET"
echo "WARNING: This will DESTROY the disks defined in the ${FLAKE_TARGET} disko config."
confirm "Proceed with wipe and install?"

# --- Clone config ---
CONFIG_DIR="/tmp/nixos-config"
rm -rf "$CONFIG_DIR"
info "Cloning configuration..."
timeout 120 git clone "$REPO_URL" "$CONFIG_DIR" || die "Clone failed"

PINNED_COMMIT=$(git -C "$CONFIG_DIR" rev-parse HEAD)
info "Repo at commit: $PINNED_COMMIT"

# Remove .git so Nix evaluates working-directory files, not the git index.
# Without this, uncommitted changes (injected hash) are invisible to nixos-install.
rm -rf "$CONFIG_DIR/.git"

# --- Password hash ---
# Pull mkpasswd + python3 via nix shell -- neither is on the NixOS ISO.
# whois package provides mkpasswd on nixpkgs.
# mutableUsers=false rewrites /etc/shadow from the Nix store on every boot.
# Hash must be correct in the closure or dk is locked after every impermanence wipe.
NX="nix shell nixpkgs#whois nixpkgs#python3 --command"

info "Setting password for ${USER_NAME}..."
echo "(input hidden -- type password and press Enter)"
PW_HASH=$($NX mkpasswd -m yescrypt) \
    || die "mkpasswd failed"
[[ "$PW_HASH" == '$y$'* ]] \
    || die "Unexpected hash format: $PW_HASH"

TARGET_NIX="$CONFIG_DIR/hosts/${FLAKE_TARGET}/default.nix"
grep -q "REPLACE_WITH_YESCRYPT_HASH" "$TARGET_NIX" \
    || die "Placeholder not found in $TARGET_NIX -- already patched in repo?"

# Write hash via temp file + python3 script file.
# Avoids heredoc stdin forwarding issues through nix shell --command.
# Avoids shell expansion of dollar signs in $y$j9T$... hash.
printf '%s' "$PW_HASH" > "$PW_FILE"

cat > "$PY_FILE" << 'PYEOF'
import sys
path = sys.argv[1]
hash_val = open(sys.argv[2]).read().strip()
content = open(path).read()
assert 'REPLACE_WITH_YESCRYPT_HASH' in content, 'Placeholder missing in ' + path
result = content.replace('REPLACE_WITH_YESCRYPT_HASH', hash_val)
assert 'REPLACE_WITH_YESCRYPT_HASH' not in result, 'Replacement produced no change'
open(path, 'w').write(result)
print('Hash injected into ' + path)
PYEOF

$NX python3 "$PY_FILE" "$TARGET_NIX" "$PW_FILE" \
    || die "Hash injection failed"

nix-instantiate --parse "$TARGET_NIX" > /dev/null \
    || die "Nix parse error after hash injection -- aborting before disko"

if grep -q "REPLACE_WITH_YESCRYPT_HASH" "$TARGET_NIX"; then
    die "Placeholder still present -- hash write failed"
fi

info "Password hash written and verified"

# --- Disko ---
# Extract the exact disko rev locked in our flake.lock.
# This guarantees we run the same disko version the config was tested against,
# not whatever upstream HEAD resolves to at install time.
info "Resolving locked disko revision from flake.lock..."
DISKO_REV=$(nix shell nixpkgs#jq --command \
    jq -er '.nodes.disko.locked.rev' "$CONFIG_DIR/flake.lock") \
    || die "Could not extract disko rev from flake.lock"
[[ -n "$DISKO_REV" ]] || die "disko rev is empty -- check flake.lock has a disko input"
info "Using disko rev: $DISKO_REV"

info "Running Disko..."
nix run "github:nix-community/disko/$DISKO_REV" -- \
    --mode destroy,format,mount \
    --flake "$CONFIG_DIR#$FLAKE_TARGET" || die "Disko failed"

for m in /mnt /mnt/boot /mnt/persist /mnt/nix; do
    mountpoint -q "$m" || die "Mount point not found: $m"
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
    echo "WARNING: No SSH host keys -- new keys generated on boot."
    echo "  Update known_hosts on machines that connect to this host."
fi

if [[ "$MACHINE_ID_AVAILABLE" -eq 1 ]]; then
    install -D -m 444 -o 0 -g 0 \
        "$BACKUP_PATH/system/machine-id" /mnt/persist/system/etc/machine-id
    info "Restored machine-id"
else
    info "Skipping machine-id -- systemd generates on first boot"
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

# Clone a clean (unpatched) copy of the repo into the user home.
# The hash-injected CONFIG_DIR is used only by nixos-install and is not persisted.
# Fatal on failure -- silently falling back to the patched tree would leak the hash
# into persisted user storage.
info "Cloning clean repo into user home (pinned to install commit)..."
timeout 120 git clone "$REPO_URL" "$USER_HOME/nixos-config" \
    || die "Clean repo clone into user home failed"
git -C "$USER_HOME/nixos-config" checkout --detach "$PINNED_COMMIT" \
    || die "Could not checkout pinned commit in user home clone"
# Remove .git -- user edits via nixos-rebuild, not git pull;
# leaving .git would let a later pull diverge from the installed system.
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
# root.hashedPassword = "" is set declaratively (passwordless, not locked).
# --no-root-passwd only skips the install-time interactive prompt.
info "Verifying root is not locked..."
ROOT_FIELD=$(nixos-enter --root /mnt -- getent shadow root 2>/dev/null | cut -d: -f2)
case "$ROOT_FIELD" in
    ""|'$'*) info "root accessible (passwordless or hashed)" ;;
    '!'*|'*') die "CRITICAL: root is locked -- TTY recovery impossible" ;;
    *) die "CRITICAL: root shadow field unrecognised: $ROOT_FIELD" ;;
esac

info "Verifying ${USER_NAME} account is not locked..."
USER_FIELD=$(nixos-enter --root /mnt -- getent shadow "${USER_NAME}" 2>/dev/null | cut -d: -f2)
case "$USER_FIELD" in
    '$y$'*|'$6$'*|'$5$'*|'$2b$'*) info "${USER_NAME} account is active" ;;
    "") die "CRITICAL: ${USER_NAME} has empty password field" ;;
    '!'*|'*') die "CRITICAL: ${USER_NAME} is locked -- hash not in closure" ;;
    *) die "CRITICAL: ${USER_NAME} shadow field unrecognised: $USER_FIELD" ;;
esac

info "Verifying bootloader..."
[[ -d /mnt/boot/EFI ]] || die "/mnt/boot/EFI missing"
[[ -n "$(ls -A /mnt/boot/EFI 2>/dev/null)" ]] \
    || die "/mnt/boot/EFI is empty -- bootloader install failed"
info "Bootloader installed"

echo ""
echo "=============================="
echo "       INSTALL SUCCESS        "
echo "=============================="
echo "Commit: $PINNED_COMMIT"
echo "Disko:  $DISKO_REV"
echo ""
echo "POST-BOOT: Set up Secure Boot once running:"
echo "  1. sudo sbctl create-keys"
echo "  2. sudo sbctl enroll-keys --microsoft"
echo "  3. Reboot -> UEFI firmware -> enable Secure Boot"
echo "  4. Edit hosts/yoga/default.nix: secureboot.enable = true"
echo "  5. sudo nixos-rebuild switch --flake .#yoga"

confirm "Reboot now?"
reboot
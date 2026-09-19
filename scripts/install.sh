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

Credentials:
  This script does NOT set login passwords. Accounts are declarative
  (users.mutableUsers = false) and take their hash from the sops secret
  dk_password_hash (secrets/hosts/<host>.yaml) at FIRST BOOT. The installer
  only provisions the host's sops identity so that decryption can succeed:
  method=ssh (yoga): the restored /etc/ssh/ssh_host_ed25519_key;
  method=age (latitude, nix-media): /var/lib/sops-nix/key.txt, restored from
  <backup>/sops/key.txt or freshly generated (fix steps printed if the
  identity is not yet a recipient of the pinned secrets yaml).

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

# --- Pre-flight ---

[[ $EUID -eq 0 ]] || die "Run as root"

export NIX_CONFIG="experimental-features = nix-command flakes"

deps=(nix git mountpoint curl timeout nixos-install mount umount find findmnt btrfs)
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

# --- Detect host features (flake eval) ---
# Truth comes from the evaluated NixOS config of the pinned commit, not from
# grepping source files — nixfmt's multiline formatting silently broke
# grep-based impermanence detection once (yoga reinstalled without the
# @blank template = initrd emergency shell on every boot).

HOST_DIR="$CONFIG_DIR/hosts/$FLAKE_TARGET"
[[ -d "$HOST_DIR" ]] || die "Host '$FLAKE_TARGET' not found in hosts/"

nix_eval() {
  # nix_eval <config-attr-path> [apply-lambda]
  local attr="$1" apply="${2:-}"
  if [[ -n "$apply" ]]; then
    nix eval --json "$CONFIG_DIR#nixosConfigurations.$FLAKE_TARGET.config.$attr" --apply "$apply"
  else
    nix eval --json "$CONFIG_DIR#nixosConfigurations.$FLAKE_TARGET.config.$attr"
  fi
}

bool_flag() {
  local v
  v=$(nix_eval "$1" "${2:-}") \
    || die "Feature detection failed at config.$1 — flake broken at pinned commit?"
  [[ "$v" == "true" ]]
}

info "Evaluating host features from the pinned flake (first eval fetches inputs)..."

HAS_DISKO=0;          bool_flag disko.devices.disk 'd: d != {}'                          && HAS_DISKO=1
HAS_IMPERMANENCE=0;   bool_flag features.impermanence.enable                             && HAS_IMPERMANENCE=1
HAS_PERSIST=0;        bool_flag fileSystems 'fs: builtins.hasAttr "/persist" fs'         && HAS_PERSIST=1
HAS_SOPS=0;           bool_flag features.sops.enable                                     && HAS_SOPS=1
HAS_SECUREBOOT=0;     bool_flag features.secureboot.enable                               && HAS_SECUREBOOT=1
SOPS_METHOD="none"
if [[ $HAS_SOPS -eq 1 ]]; then
  SOPS_METHOD=$(nix eval --raw "$CONFIG_DIR#nixosConfigurations.$FLAKE_TARGET.config.features.sops.method") \
    || die "Could not evaluate features.sops.method"
fi

if [[ $HAS_PERSIST -eq 1 ]]; then
  PERSIST_SYSTEM="/mnt/persist/system"
else
  PERSIST_SYSTEM="/mnt"
fi

info "Host:         $FLAKE_TARGET"
info "Disko:        $([ $HAS_DISKO -eq 1 ] && echo 'yes' || echo 'no')"
info "Impermanence: $([ $HAS_IMPERMANENCE -eq 1 ] && echo 'yes' || echo 'no')"
info "sops:         $([ $HAS_SOPS -eq 1 ] && echo "enabled (method=$SOPS_METHOD)" || echo 'disabled')"

# --- Backup prompt ---

read -rp "Backup USB path (e.g. /mnt/usb, or none): " BACKUP_PATH
USE_BACKUP=1
if [[ "$BACKUP_PATH" == "none" || ! -d "$BACKUP_PATH" ]]; then
  echo "WARNING: No backup path - SSH keys and machine-id will be freshly generated."
  echo "  On sops hosts this also means no identity restore (fresh key generated"
  echo "  for method=age) - see the credentials note in the usage text."
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
  info "Skipping Disko (no disko devices for this host)"
  info "Expecting partitions already mounted under /mnt"
fi

# --- Verify mount points ---

info "Verifying mount points..."
mountpoint -q /mnt || die "/mnt is not mounted"

if [[ $HAS_DISKO -eq 1 ]]; then
  # Disko hosts mount /boot and potentially /persist, /nix
  mountpoint -q /mnt/boot 2>/dev/null || echo "WARNING: /mnt/boot not mounted"
  if [[ $HAS_IMPERMANENCE -eq 1 ]]; then
    mountpoint -q /mnt/persist || die "/mnt/persist is not mounted (required for impermanence)"
    mountpoint -q /mnt/nix 2>/dev/null || echo "WARNING: /mnt/nix not mounted"
  fi
else
  # Non-disko: at minimum /mnt and /mnt/boot should be mounted
  mountpoint -q /mnt/boot 2>/dev/null || echo "WARNING: /mnt/boot not mounted"
fi

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
  mkdir -p /tmp/btrfs-top/@/{nix,persist,boot,home,etc,tmp,var/log,var/lib,var/lib/sops-nix,var/lib/sbctl}
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

# --- Credentials note (declarative passwords, applied at first boot) ---

info "Credentials: login passwords are NOT set at install time. The hash from"
info "secrets/hosts/$FLAKE_TARGET.yaml (dk_password_hash) applies at FIRST"
info "BOOT via sops - the identity is provisioned below, after state restore."

# --- State Restoration (System) ---

info "Restoring system identity..."

if [[ "$USE_BACKUP" -eq 1 ]] && [[ -f "$BACKUP_PATH/ssh/ssh_host_ed25519_key" ]]; then
  info "Restoring SSH host keys..."
  mkdir -p "$PERSIST_SYSTEM/etc/ssh"
  cp -a "$BACKUP_PATH"/ssh/ssh_host_* "$PERSIST_SYSTEM/etc/ssh/"
  chmod 600 "$PERSIST_SYSTEM/etc/ssh/"*_key
  chmod 644 "$PERSIST_SYSTEM/etc/ssh/"*.pub 2>/dev/null || true
  chown -R 0:0 "$PERSIST_SYSTEM/etc/ssh"
else
  echo "WARNING: No SSH host keys - new keys generated on boot."
  echo "  On method=ssh sops hosts the identity changes with them (runbook §5)."
fi

if [[ "$MACHINE_ID_AVAILABLE" -eq 1 ]]; then
  install -D -m 444 -o 0 -g 0 \
    "$BACKUP_PATH/system/machine-id" "$PERSIST_SYSTEM/etc/machine-id"
  info "Restored machine-id"
else
  info "Skipping machine-id - systemd generates on first boot"
fi

# --- SOPS identity provisioning (decrypt dk_password_hash at first boot) ---

SOPS_KEY_INSTALLED=0
SOPS_RECIPIENT_OK=0
SOPS_PUBKEY=""
FRESH_AGE_KEY=0

if [[ $HAS_SOPS -eq 1 ]]; then
  SECRETS_YAML="$CONFIG_DIR/secrets/hosts/$FLAKE_TARGET.yaml"
  [[ -f "$SECRETS_YAML" ]] || die "sops enabled but $SECRETS_YAML missing in the pinned clone"

  yaml_recipients() {
    nix shell nixpkgs#yq-go --command \
      yq '.sops.age[].recipient' "$SECRETS_YAML" 2>/dev/null || true
  }

  if [[ "$SOPS_METHOD" == "ssh" ]]; then
    # Identity IS the (persisted) SSH host key restored above.
    IDENTITY_KEY="$PERSIST_SYSTEM/etc/ssh/ssh_host_ed25519_key"
    if [[ -f "$IDENTITY_KEY" && -f "$IDENTITY_KEY.pub" ]]; then
      SOPS_KEY_INSTALLED=1
      SOPS_PUBKEY=$(nix shell nixpkgs#ssh-to-age --command \
        sh -c "ssh-to-age < $IDENTITY_KEY.pub" 2>/dev/null \
        | grep -o 'age1[a-z0-9]*' | head -1 || true)
    fi
  elif [[ "$SOPS_METHOD" == "age" ]]; then
    KEY_TARGET="$PERSIST_SYSTEM/var/lib/sops-nix/key.txt"
    if [[ "$USE_BACKUP" -eq 1 ]] && [[ -f "$BACKUP_PATH/sops/key.txt" ]]; then
      info "Restoring sops age key from backup..."
      install -D -m 600 -o 0 -g 0 "$BACKUP_PATH/sops/key.txt" "$KEY_TARGET"
    fi
    if [[ ! -f "$KEY_TARGET" ]]; then
      info "No sops age key available - generating a fresh identity..."
      mkdir -p "$(dirname "$KEY_TARGET")"
      nix shell nixpkgs#age --command age-keygen -o "$KEY_TARGET" >/dev/null 2>&1 \
        || die "age-keygen failed"
      chmod 600 "$KEY_TARGET"
      FRESH_AGE_KEY=1
    fi
    if [[ -f "$KEY_TARGET" ]]; then
      SOPS_KEY_INSTALLED=1
      SOPS_PUBKEY=$(nix shell nixpkgs#age --command \
        age-keygen -y "$KEY_TARGET" 2>/dev/null \
        | grep -o 'age1[a-z0-9]*' | head -1 || true)
    fi
  else
    die "Unknown sops method: $SOPS_METHOD"
  fi

  if [[ $SOPS_KEY_INSTALLED -eq 1 ]] && [[ -n "$SOPS_PUBKEY" ]]; then
    if yaml_recipients | grep -qx "$SOPS_PUBKEY"; then
      SOPS_RECIPIENT_OK=1
      info "sops identity OK: provisioned key is a recipient of the pinned yaml"
    fi
  fi
fi

# --- State Restoration (User) ---

info "Restoring user data for ${USER_NAME}..."

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

info "Verifying bootloader..."
[[ -d /mnt/boot/EFI ]] || die "/mnt/boot/EFI missing"
[[ -n "$(ls -A /mnt/boot/EFI 2>/dev/null)" ]] \
  || die "/mnt/boot/EFI is empty - bootloader install failed"
info "Bootloader installed"

# Accounts are declarative and locked at install time by design: sops secrets
# decrypt at FIRST boot (users.mutableUsers=false re-applies the hash from
# dk_password_hash then). What we CAN verify now is the sops identity chain.
FIRST_BOOT_CREDENTIALS_OK=1
if [[ $HAS_SOPS -eq 1 ]]; then
  if [[ $SOPS_KEY_INSTALLED -eq 0 ]]; then
    FIRST_BOOT_CREDENTIALS_OK=0
    echo "WARNING: no sops identity provisioned - first boot cannot decrypt"
    echo "  dk_password_hash. Accounts stay LOCKED (GDM autologin still grants"
    echo "  the desktop; sudo will not work until this is fixed)."
  elif [[ $SOPS_RECIPIENT_OK -eq 0 ]]; then
    FIRST_BOOT_CREDENTIALS_OK=0
    echo "WARNING: the provisioned sops identity is NOT a recipient of"
    echo "  secrets/hosts/$FLAKE_TARGET.yaml at pinned commit $PINNED_COMMIT.$([[ $FRESH_AGE_KEY -eq 1 ]] && echo ' (freshly generated key - expected until enrolled)')"
    echo "  First boot cannot decrypt dk_password_hash -> accounts stay LOCKED"
    echo "  (GDM autologin still grants the desktop; sudo will not work)."
  else
    info "First-boot credentials: OK (sops identity provisioned and enrolled)"
  fi

  if [[ $FIRST_BOOT_CREDENTIALS_OK -eq 0 ]]; then
    cat <<FIX

Fix from a machine holding ANY current recipient's key — the admin key on
yoga, or this device itself (see SOPS_RUNBOOK.md §3/§5 for the procedures):
FIX
    if [[ "$SOPS_METHOD" == "age" && -n "$SOPS_PUBKEY" ]]; then
      echo "  1. Add this recipient for secrets/hosts/$FLAKE_TARGET.yaml in .sops.yaml:"
      echo "       $SOPS_PUBKEY"
    else
      echo "  1. Derive the identity's recipient and add it in .sops.yaml"
      echo "     (method=ssh: ssh-to-age < ssh_host_ed25519_key.pub)."
    fi
    cat <<FIX
  2. nix shell nixpkgs#sops -c sops updatekeys secrets/hosts/$FLAKE_TARGET.yaml
  3. commit + push
  4. Rebuild this host from the new commit (after first boot, or re-run this
     installer from the updated repo).
If the password stored in the yaml is unknown, rotate it while at it:
  nix shell nixpkgs#sops -c sops secrets/hosts/$FLAKE_TARGET.yaml   # dk_password_hash
  nix shell nixpkgs#whois --command mkpasswd -m yescrypt
FIX
  fi
fi

# --- Summary ---

echo ""
echo "=============================="
echo "       INSTALL SUCCESS        "
echo "=============================="
echo "Host:   $FLAKE_TARGET"
echo "Commit: $PINNED_COMMIT"
[[ $HAS_DISKO -eq 1 ]] && echo "Disko:  $DISKO_REV"
if [[ $HAS_SOPS -eq 1 ]]; then
  if [[ $FIRST_BOOT_CREDENTIALS_OK -eq 1 ]]; then
    echo "sops:   identity OK"
  else
    echo "sops:   ATTENTION REQUIRED (see warning above)"
  fi
fi
echo ""

# --- Post-boot instructions (host-aware) ---

if [[ $HAS_SECUREBOOT -eq 1 ]]; then
  echo "POST-BOOT: Set up Secure Boot once running:"
  echo "  1. sudo sbctl create-keys"
  echo "  2. sudo sbctl enroll-keys --microsoft"
  echo "  3. Reboot -> UEFI firmware -> enable Secure Boot"
  echo "  4. Rebuild: sudo nixos-rebuild switch --flake .#$FLAKE_TARGET"
else
  echo "POST-BOOT: Review and rebuild as needed:"
  echo "  sudo nixos-rebuild switch --flake .#$FLAKE_TARGET"
fi

if [[ $FIRST_BOOT_CREDENTIALS_OK -eq 0 ]]; then
  echo ""
  echo "NOTE: Do not rely on sudo after first boot until the sops fix above is done."
fi

confirm "Reboot now?"
reboot

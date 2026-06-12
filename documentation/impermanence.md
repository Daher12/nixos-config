# Btrfs Root Rollback (`features.impermanence`)

Defined in `modules/features/impermanence.nix`. Enabled on **yoga** via
`hosts/yoga/default.nix`.

---

## Data Model

The root filesystem uses **split Btrfs subvolumes**:

```
Btrfs top-level (subvolid=5)
├── @           → mounted at /      — wiped on every boot
├── @blank      → template snapshot — read-only, never mounted
├── @nix        → mounted at /nix   — persistent
├── @persist    → mounted at /persist — persistent
└── ...         (other subvolumes)
```

Each boot:

1. `@blank` is validated (exists, is read-only, has all required mount-point directories)
2. `@` is recursively deleted (if it exists)
3. A fresh read-write snapshot is created from `@blank` → `@`
4. `/tmp` permissions are set to 1777
5. The system mounts the persistent subvolumes (`/nix`, `/persist`, etc.) on
   top of the empty mount-point directories in `@`

All persistent data lives on the `/persist` subvolume. The `@` subvolume
contains only the NixOS skeleton (symlinks into `/nix/store`, mount-point
directories, `/etc` files managed by `environment.persistence`).

---

## Boot Sequence

```
Kernel → LUKS device appears
  → rollback-root service runs
      → mount Btrfs top-level
      → validate @blank exists
      → validate @blank is read-only (btrfs property get)
      → validate @blank has all required mount-point directories
      → delete @ subvolume
      → snapshot @blank → @
      → set /tmp permissions
      → unmount Btrfs top-level  (or trap fires on error)
  → sysroot.mount mounts @ to /sysroot
  → initrd-nixos-activation waits for:
      - /sysroot/nix/store  (nix subvolume must be mounted)
      - /sysroot/persist    (persist subvolume must be mounted)
  → activation completes
  → switch-root to real system
  → impermanence module bind-mounts each persist entry to its target path under /
  → multi-user.target
```

Failure handling: any error in the rollback script triggers `set -euo pipefail`,
which aborts the service. `OnFailure = "emergency.target"` drops to an initrd
emergency shell where the user can investigate. The `@` subvolume is never
touched unless `@blank` passes all validations, so data is preserved.

---

## Template Validation

The `@blank` snapshot must pass three checks at every boot:

1. **Exists** — `btrfs subvolume show` confirms the subvolume is present.
2. **Read-only** — `btrfs property get -ts @blank ro` must return `ro=true`.
   The install script creates `@blank` with `btrfs subvolume snapshot -r` to
   set this flag. If `@blank` was made writable (e.g. for template updates),
   the flag must be restored with `btrfs property set -ts @blank ro true`.
3. **Required directories** — the following mount-point directories must exist:

```
nix persist boot home etc tmp var
var/log var/lib var/lib/sops-nix var/lib/sbctl
```

These are **mount points** for persistent subvolumes and special paths. They
must exist as empty directories inside `@blank`. If any path is missing, the
boot aborts with a clear error message before `@` is modified.

### Adding a New Btrfs Subvolume Under `/`

If you add a new Btrfs subvolume mount via `fileSystems` (e.g.,
`/var/lib/docker` as a separate subvolume), the mount-point directory must
exist inside `@blank`. You must:

1. Add the path to the validation list in `modules/features/impermanence.nix`
   (the `for d in \` block in the rollback script)
2. Update `@blank` to contain the new directory (see below)

Note: plain `environment.persistence` entries (bind-mounts from `/persist`) do
**not** require a `@blank` update — the impermanence module creates target
directories at runtime. Only new filesystem-level subvolume mounts need the
template.

---

## Updating `@blank`

The `@blank` template is a static snapshot. It only needs updating when the
list of required mount-point directories changes (see above). In practice, this
is rare.

**When to update:**

- Adding a new Btrfs subvolume that mounts under `/` (e.g., `/var/lib/docker`)
- Changing the boot partition layout
- Adding a new persistent directory that requires a parent path not currently
  in `@blank`

**How to update:**

```sh
# On the impermanence host (yoga):
sudo mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
sudo btrfs subvolume snapshot -r /mnt/@ /mnt/@blank-tmp
sudo btrfs subvolume delete /mnt/@blank
sudo mv /mnt/@blank-tmp /mnt/@blank
sudo umount /mnt
```

Or from the initrd emergency shell after a failed validation:

```sh
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt
btrfs subvolume snapshot -r /mnt/@ /mnt/@blank
umount /mnt
reboot
```

**Hard rule:** Update `@blank` before rebooting after any change to the
partition scheme or subvolume layout. If you forget, the next boot will fail
with a validation error (safe) or, worse, the system will boot without the new
mount point (silent data loss risk for anything written to that path).

---

## Required Persistence Entries

The yoga host config (`hosts/yoga/default.nix`) defines these persistence
rules. Cross-check when adding new services:

| Path | Persisted via | Type |
|------|---------------|------|
| `/var/log` | `environment.persistence."/persist/system"` | Directory |
| `/var/lib/{bluetooth,iwd,nixos,systemd,tailscale,sops-nix,upower,libvirt,gdm,AccountsService,fwupd,colord}` | Same | Directories |
| `/var/db/sudo/lectured` (NixOS sudo lecture tracking) | Same | Directory |
| `/etc/machine-id` | Same | File |
| `/etc/ssh/ssh_host_*` | Same | Files (with `parentDirectory.mode`) |
| `/etc/NetworkManager/system-connections` | Same | Directory |
| `/etc/brave/policies/managed/bloat.json` | Same | File |
| `/persist` (user dirs) | `environment.persistence."/persist"` | User directories under `users.dk` |

The two persistence scopes:
- **`/persist/system`** — system-level state: service data (`/var/lib/*`),
  SSH keys, NetworkManager connections, machine identity
- **`/persist`** — user home directories: desktop folders, config repos

---

## Recovery Procedures

### Boot fails with "missing template snapshot"

`@blank` has been accidentally deleted or corrupted. The old `@` subvolume
still exists (the script checks `@blank` before touching `@`).

From the initrd emergency shell:

```sh
# Mount the Btrfs top-level
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt

# Check if @ still exists
btrfs subvolume show /mnt/@

# Re-create @blank from @  (read-only, booting without rollback for one cycle)
btrfs subvolume snapshot -r /mnt/@ /mnt/@blank

# Verify
btrfs subvolume show /mnt/@blank

umount /mnt
exit  # continues booting
```

### Boot fails with "not a read-only snapshot"

`@blank` exists but does not have the Btrfs read-only flag set. This happens
when `@blank` was made writable (e.g. to add a directory) and the flag was
not restored. The rollback script refuses to snapshot a writable template
because it could be corrupted.

From the initrd emergency shell:

```sh
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt

# Restore the read-only flag
btrfs property set -ts /mnt/@blank ro true

# Verify
btrfs property get -ts /mnt/@blank ro
# Should print: ro=true

umount /mnt
exit
```

### Boot fails with "missing required path"

A directory is missing from `@blank`. Likely caused by a partition layout
change without a corresponding `@blank` update.

From the initrd emergency shell:

```sh
mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt

# RECOMMENDED: recreate @blank from current @ (reliable, handles all cases)
btrfs subvolume delete /mnt/@blank
btrfs subvolume snapshot -r /mnt/@ /mnt/@blank

# ALTERNATIVE: if @ is also corrupted, make @blank temporarily writable
# and manually add only the missing path:
#   btrfs property set -ts /mnt/@blank ro false
#   mkdir -p /mnt/@blank/<missing-path>
#   btrfs property set -ts /mnt/@blank ro true

umount /mnt
exit
```

---

## Initrd Constraints

The rollback script runs inside the systemd-based initrd. Only binaries
explicitly listed in `boot.initrd.systemd.storePaths` are available. The
current list:

- `btrfs` (btrfs-progs)
- `mount`, `umount` (util-linux)
- `chmod` (coreutils)

**Not available** in the initrd PATH: `grep`, `awk`, `sed`, `cut`, `find`,
`ls`, `cat`, `echo` (as standalone binaries — the shell builtin `echo` works).
The script uses only:

- `btrfs` subcommands for all filesystem operations
- Bash builtins (`read`, `while`, `[ ]`, `case`, parameter expansion) for
  control flow and string manipulation

If you add new logic to the rollback script, avoid external commands not in
`storePaths`. Use `btrfs property get` for property checks and bash builtins
for parsing. Nix `''` strings require `''${` to emit a literal `${` into the
shell script (e.g. `''${var##pattern}` for bash parameter expansion).

---

## Cross-References

- Module definition: `modules/features/impermanence.nix`
- Host config: `hosts/yoga/default.nix`
- Install script: `scripts/install.sh` (creates `@blank` during initial setup)
- Disk layout: `hosts/yoga/disks.nix` (Disko configuration)
- Secure Boot PKI persistence: `modules/features/secureboot.nix` (persists
  `/var/lib/sbctl` via impermanence)
- SOPS key persistence: `modules/features/sops.nix` (key stored at
  `/persist/system/var/lib/sops-nix/`, bind-mounted to `/var/lib/sops-nix/`
  at runtime)

# SOPS Runbook — architecture, fixes applied 2026-09-13, remaining operator plan

This is the single reference for the secrets setup. Nothing here blocks yoga
after merge + rebuild — the only REQUIRED device work is §3 (latitude and
nix-media re-encryption, ~10 min per device).

---

## 1. Architecture (target state)

| Identity | Type | Private key location | Used by |
|---|---|---|---|
| `admin_david` `age1ff0ly0…` | operator age key | yoga: `~/.config/sops/age/keys.txt` (persisted) | you, to create/edit **every** file |
| `host_yoga` `age12eq9rt…` | derived from yoga's SSH host key (fingerprint `SHA256:P400w2IPh+Fgrbu/JK1vwd6aAxP1UdtYG8cmCw7jhdU`) | none needed — sops-nix converts `/persist/system/etc/ssh/ssh_host_ed25519_key` at activation (`method = "ssh"`) | yoga |
| `host_nix-media` `age1ntm37…` | classic age key | nix-media: `/var/lib/sops-nix/key.txt` | nix-media |
| `host_latitude` `age1n6s0w…` | classic age key | latitude: `/var/lib/sops-nix/key.txt` | latitude |

Recipient sets (`secrets/hosts/<host>.yaml`): `[admin_david, <host>]` — rules
in `.sops.yaml`.

**`dk_password_hash` is consumed on EVERY sops-enabled host**
(`modules/core/users.nix` wires `"${mainUser}_password_hash"` into
`hashedPasswordFile`) — never remove it from a per-host file; removing it
breaks activation with a lockout-guard assertion or a missing-secret failure.

Current files:

| File | Secrets | State |
|---|---|---|
| `yoga.yaml` | `dk_password_hash`, `root_password_hash` | ✅ fixed 2026-09-13: re-encrypted to the ssh-derived identity + current admin key |
| `nix-media.yaml` | `grafana_admin_password`, `ntfy_url`, `ntfy_topic`, `dk_password_hash` | ⚠️ still encrypted to the RETIRED admin key → §3 (all keys stay; nothing dead inside except nothing — keep all) |
| `latitude.yaml` | `dk_password_hash` (live) + `wifi_home_psk`, `wifi_work_psk` (dead, 0 config refs) | ⚠️ still encrypted to the RETIRED admin key → §3 (drops the two wifi PSKs) |

Why this design: yoga's on-device decryption needs no manual key provisioning
(identity anchored to the persisted SSH host key — survives impermanence wipes
and the disko rebuild blueprint), while every file stays editable from yoga
with your personal key.

Everyday commands (on yoga, as `dk`):

```bash
# edit
nix shell nixpkgs#sops -c sops secrets/hosts/<host>.yaml
# verify you can decrypt
nix shell nixpkgs#sops -c sops -d secrets/hosts/<host>.yaml > /dev/null && echo OK
# see which keys a file is encrypted to
nix shell nixpkgs#yq-go -c yq '.sops.age[].recipient' secrets/hosts/<host>.yaml
```

---

## 2. What was wrong (evidence, 2026-09-13)

- `latitude.yaml` + `nix-media.yaml` are encrypted to the **retired** admin
  key `age1vzw0xw2d6…` → undecryptable from yoga (verified live:
  `no identity matched any of the recipients`).
- `.sops.yaml` referenced a yoga host key `age126lkzv0…` whose private half
  existed **nowhere** — `/persist/system/var/lib/sops-nix/` and
  `/var/lib/sops-nix/` are both empty on yoga. At the next `switch`,
  activation would have failed to decrypt `yoga.yaml` (root + user password
  hashes unavailable). Fixed by anchoring yoga's identity to the SSH host key.
- `secrets/hosts/yoga.yaml.backup` (gitignored, from March) was encrypted to
  the retired admin key AND a dead yoga key — removed.

---

## 3. OPERATOR PLAN — re-encrypt latitude + nix-media (required, ~10 min each)

Goal: both files encrypted to `[admin_david (current), <host>]`; on latitude
additionally drop the two dead wifi PSKs. Each device can decrypt its own old
file (its key.txt is a recipient); yoga cannot — so this runs ON the device.

**Step 0 — from yoga:** push the `testing` branch (or merge it to main if you
already switched yoga onto it), then on the target device pull it into the
checkout your config builds from (e.g. `cd /etc/nixos && sudo git pull`).
All commands below run on the device as root.

**Step 1 — decrypt to tmpfs, drop dead keys (latitude only), re-encrypt:**

```bash
cd /etc/nixos
# decrypt with the device identity to RAM-backed tmpfs (root only)
SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops -d secrets/hosts/<host>.yaml > /run/plain.yaml

# LATITUDE ONLY — drop the dead wifi keys (must print 0 afterwards):
nix shell nixpkgs#yq-go -c yq -i 'del(.wifi_home_psk, .wifi_work_psk)' /run/plain.yaml
grep -c wifi_ /run/plain.yaml

# re-encrypt through the repo's creation rules and install
cp /run/plain.yaml secrets/hosts/<host>.yaml
sops -e secrets/hosts/<host>.yaml > /run/enc.yaml
mv /run/enc.yaml secrets/hosts/<host>.yaml
rm -f /run/plain.yaml
```

**Step 2 — verify on the device:**

```bash
SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops -d secrets/hosts/<host>.yaml > /dev/null && echo device-decrypt OK
nix shell nixpkgs#yq-go -c yq '.sops.age[].recipient' secrets/hosts/<host>.yaml
# expect exactly: age1ff0ly0… (admin_david) + the device's own age1n6s0w…/age1ntm37…
```

**Step 3 — get the file back into git** (choose one):

- Variant A (git on device): `sudo git add secrets/hosts/<host>.yaml &&
  sudo git commit -m "sops: re-encrypt <host>.yaml to current keys" && sudo git push`
- Variant B (copy to yoga): from yoga
  `scp <user>@<device>:/etc/nixos/secrets/hosts/<host>.yaml /home/dk/nixos-config/secrets/hosts/`
  then commit + push from yoga.

**Step 4 — rebuild the device** with your usual flow (`./scripts/update-safe`).
Verify the rendered secrets and that login paths still work:

```bash
ls /run/secrets/            # dk_password_hash (+ ntfy/grafana secrets on nix-media) present
```

**Step 5 — final cross-check from yoga:** after pulling,
`nix shell nixpkgs#sops -c sops -d secrets/hosts/<host>.yaml > /dev/null && echo OK`
— yoga can now edit both files. Done.

Failure handling: if Step 1's decrypt fails with `no identity matched`, the
device key.txt is not a recipient either — STOP, delete nothing; recovery is
only possible from a backup of the retired admin key. For anything else, the
original file is still in git: `git checkout -- secrets/hosts/<host>.yaml`.

wifi_home_psk note (from the 2026-09-09 audit): its value transited a session
transcript once. Deleting it here (latitude) removes it from the repo; if the
same PSK is still used by any client profile, rotate it at the router/AP.

---

## 4. Optional later: migrate latitude/nix-media to ssh-derived identities

Yoga-style (`method = "ssh"`): persist `/etc/ssh/ssh_host_ed25519_key` on the
device, derive `ssh-to-age < ssh_host_ed25519_key.pub`, swap the `&host_*`
entry in `.sops.yaml`, `sops updatekeys secrets/hosts/<host>.yaml` (works from
yoga via admin_david), set `method = "ssh"` in the host module, rebuild. Kills
the last manually-provisioned key files. Not required — key.txt works.

---

## 5. Rotation procedures (for the future)

**Rotate the admin (operator) key:** generate
(`age-keygen -o ~/.config/sops/age/keys.txt.new`), add the new pubkey to
`.sops.yaml` alongside the old, `sops updatekeys` every file, remove the old
pubkey, `updatekeys` again, rebuild nothing (host identities unchanged).

**yoga host identity:** automatically follows the SSH host key. If that key is
ever regenerated (manual reinstall without restoring
`/persist/system/etc/ssh`), re-derive
(`ssh-to-age < /persist/system/etc/ssh/ssh_host_ed25519_key.pub`), update
`&host_yoga`, then `sops updatekeys secrets/hosts/yoga.yaml` — decryptable via
admin_david, so this works from yoga without the host key.

**Device key.txt (latitude/nix-media):** generate a new pair, add the pub to
`.sops.yaml`, `updatekeys` from yoga, replace the device's key.txt.

**After ANY rotation:** commit, rebuild affected hosts, verify
`ls /run/secrets/` and that a service using the secrets still runs.

---

## 6. Troubleshooting

- `no identity matched any of the recipients` → the file is encrypted to keys
  you don't hold; compare §1's recipient-inspect command against `.sops.yaml`.
- Boot/activation failure after a sops change → boot the previous generation
  from the GRUB menu, `git revert`, rebuild. sops failures occur at
  activation, not in the initrd — the system still boots.
- `nixos-rebuild dry-build` does NOT validate secret-file contents (it never
  reads the encrypted files) — a missing key inside a file only surfaces at
  `switch`. After any file surgery, always `sops -d` AND check the key list
  (`sops -d file | grep -E '^[a-z_]+:'`).
- `sops -e -i` on a plaintext file errors `sops metadata not found` (observed
  2026-09-13) → use the redirect form: `sops -e file > /tmp/enc && mv /tmp/enc file`.

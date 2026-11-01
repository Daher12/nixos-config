---
name: install-sh-audit-2026-09-17
description: scripts/ audit 2026-09-17 → install.sh FIXED in the same session
  (flake-eval detection, sops identity provisioning + recipient cross-check,
  honest verification), staged uncommitted — usable only after commit+push;
  update-safe usable+current
metadata:
  node_type: memory
  type: project
  source_session: sess_b41281f9-e28d-4664-bbb0-64d8cea10e82
  originSessionId: sess_b41281f9-e28d-4664-bbb0-64d8cea10e82
---

`scripts/` audited then install.sh REWRITTEN on branch `testing`, 2026-09-17
(scripts/install.sh + REPO_OVERVIEW installer section staged, NOT committed).

**Audit findings (all four defects):** (1) impermanence grep needed one line —
yoga's multiline config detected as NO → @blank skipped → reinstall boots to
initrd emergency.target; (2) local-passwords yescrypt write was dead code
(users.nix goes straight to sops dk_password_hash; nixpkgs
update-users-groups.pl only warns on missing hashedPasswordFile, user created
locked `!`) → the `$y$` getent post-checks always false-CRITICAL-died after a
successful nixos-install; (3) backup restore never provisioned
/var/lib/sops-nix/key.txt → latitude/nix-media fresh installs fully locked out;
(4) script clones from REMOTE → unpushed work invisible to it.

**Fixes implemented (same session, user asked for yoga+latitude):**
- Detection = flake eval of the pinned clone: `features.impermanence.enable`,
  `fileSystems ? "/persist"`, `disko.devices.disk != {}` (**NOT
  `disko.devices != {}` — the disko module's default skeleton makes that always
  true; `.disk` is the clean discriminator**), `features.sops.enable`/`.method`,
  `features.secureboot.enable`; dies loudly on eval failure. Detection section
  run verbatim per host, all flags correct: yoga disko+imp+persist+sops(ssh)+sb;
  latitude disko+sops(age)+sb (**secureboot inherited mkDefault from laptop
  profile — latitude was silently missing sbctl instructions under the old
  impermanence gating**); nix-media no-disko+sops(age).
- Credentials: mkpasswd prompt/local-passwords/getent checks removed; usage
  text explains passwords apply at FIRST boot from sops.
- NEW sops identity provisioning after state restore: method=ssh → verify
  restored SSH host key, derive recipient via ssh-to-age; method=age → restore
  `<backup>/sops/key.txt` else generate fresh age key at
  `/var/lib/sops-nix/key.txt`; pubkey cross-checked against the pinned yaml's
  `.sops.age` recipients (yq) — mismatch prints concrete runbook fix steps
  pointing at the ON-DEVICE path (§3), since latitude's yaml admin recipient is
  the STALE key (current admin can't edit it; the device key is an existing
  recipient).
- sbctl post-boot instructions gated on eval'd secureboot; deps +=
  find findmnt btrfs (were used post-destructive-steps without pre-flight check).

**Validated:** bash -n, shellcheck 0 findings, `set -e` `f && X=1` pattern
proven safe, recipient extraction tested on the real three yamls, age-keygen
round-trip (0600). NOT destructively end-to-end tested (needs installer ISO).

**Why/How to apply:** usable only after the staged set is committed+pushed
(script clones the remote). yoga = bring backup USB (SSH keys + machine-id →
full chain checks out). latitude = best with backup USB **including
sops/key.txt** (original key IS an enrolled recipient → clean first-boot
unlock); without it a fresh key is generated → first boot = autologin desktop,
no sudo until the printed runbook steps + rebuild. nix-media fixed for free.
Related: [[latitude-disko-opencode]], [[sops-identity-architecture-2026-09-13]].

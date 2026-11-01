---
name: audit-fixes-2026-10-04
description: Full-repo audit 2026-10-04 + P1/P2 fixes STAGED on lucid-testing
  (12 files), user decisions on Grafana/Jellyfin, P3 backlog list
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e9f4c973-dabe-4329-8866-be918689465f
---

Full audit 2026-10-04 (3 Explore agents + verification). Fixes STAGED uncommitted on lucid-testing (12 files, 85+/116−), QC green: flake check 0, dry-builds ×3 exit 0, eval-diff proof IDENTICAL on all hosts, opencode builds against 26.05.

**User decisions (do not re-litigate):**
- Grafana secret_key stays hardcoded + in REPO_OVERVIEW — known public sample value, user says tailnet-only makes it fine.
- Jellyfin `0.0.0.0:8096` stays — two LAN devices call it directly WITHOUT tailscale. Comment added in docker.nix.
- `core.users.description` left per-host: yoga/latitude "David", nix-media "User" (unset default). Unify = set nix-media `core.users.description = "David"`.

**Applied:** opencode `inputs.nixpkgs.follows = "nixpkgs"` (second unstable-2026-04 eval gone from lock; libstdc++ wrap in home/opencode.nix left untouched — may be removable later); SSH mgmt-LAN nft rule centralized as `core.openssh.mgmtLanCidr` (emits rule for services.openssh.ports, mkIf nftables); core.boot defaults flipped to fleet values (bgrt theme, tmpfs enable=true default size 2G); yoga/latitude core blocks slimmed; Nautilus + `.pki/nssdb` persistence on yoga; Brave `--password-store=basic` documented; mnamer apiKeys options removed (store-path footgun, sops-note left); REPO_OVERVIEW 4 fixes (date, real extension lists Firefox=uBlock+Bitwarden / Brave=CNL Decryptor, litellm sidecar in secrets list, openssh row).

**P3 backlog (reported, deliberately not fixed):** dead assertions (power-tlp 18-24, sops.nix 54-59), optimizeForServer×zram swappiness conflict, dead features.filesystem.mountOptions, nas.nix hostname literal, NFS `*` export, dhcpReservations pairing assert, btrfs-balance Persistent timer, nix.nix magic bytes, ryzen-tdp option descriptions, untyped power-tlp settings, NM-wait-online stub on non-NM, redundant mkForces (secureboot.nix:27, oomd.nix:37), duplicated desktop assertions, sudoTimeout comment, latitude nvidia-disable no-op, nix-media stale useDHCP line, ext4 root no noatime, yoga-gnome attr dup, lucid runtimeInputs missing python3/awww, xdg dirs written twice, fontFamily dup, git insteadOf breadth, zcode maintainers=[], theme.nix stale DMS comment + Berlin coords hardcoded in darkman, update-safe no lock rollback hint, install.sh `rm -rf .git` breaks update-safe on fresh installs.

User next: switch yoga (or both) + commit. Related: [[obsidian-litellm-integration-2026-10-04]], [[audit-fixes-2026-10-03]].

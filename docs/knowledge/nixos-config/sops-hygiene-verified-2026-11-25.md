---
name: sops-hygiene-verified-2026-11-25
description: 2026-11-25 Q&A — user asked whether committing .sops.yaml (host
  public keys + admin recipient) to GitHub is safe; verified YES, repo sops
  hygiene intact; re-encryption of latitude.yaml/nix-media.yaml still open
metadata:
  node_type: memory
  type: project
  originSessionId: sess_25d8c8b5-808f-4459-92ed-8f375363dc19
---

User asked 2026-11-25 whether `.sops.yaml` in the public GitHub repo (host age keys + admin_david recipient) is "right". Verified and answered: **yes, correct and standard**.

Facts checked (do not re-verify):
- `.sops.yaml` lines 28–32 contain only age **public** recipients (`age1…`) — safe to publish by design (recipient list).
- Repo-wide grep for `AGE-SECRET-KEY` (private keys): zero hits.
- `secrets/hosts/yoga.yaml` confirmed fully encrypted (`ENC[AES256_GCM,…]` blobs).
- Private halves live only on devices: admin key at `~/.config/sops/age/keys.txt` on yoga; host_latitude/host_nix-media at `/var/lib/sops-nix/key.txt`; host_yoga derives from SSH host key (`features.sops.method = "ssh"`, no key.txt needed, survives impermanence wipes).

Still open (pre-existing, noted in the file's own comments, not caused by this Q&A): `secrets/hosts/latitude.yaml` and `secrets/hosts/nix-media.yaml` are still encrypted to the RETIRED admin key — pending re-encryption per `SOPS_RUNBOOK.md §3` (user-run; also recorded in [[audit-fixes-2026-11-18]]). Side files like nix-media-litellm.yaml use the `(-[a-z0-9-]+)?` path_regex until then. Not a leak risk if the retired private key was destroyed; it only blocks editing those two files from yoga.

Related: [[no-secrets-in-chat]].

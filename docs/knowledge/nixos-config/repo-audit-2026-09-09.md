---
name: repo-audit-2026-09-09
description: Repo audit 2026-09-09 — remediation COMMITTED+PUSHED by user
  (db15a2a, on e8467d4 zen revert); vulkan-tools regression from the s2h sed
  extraction RESOLVED (tree clean on testing @ b8a9008, dry-build + full
  build of yoga green 2026-09-13); recheck fix behaviorally A/B tested;
  home-files scan = only intended fish diff; manifest.json closure change is
  upstream nixpkgs
metadata:
  node_type: memory
  type: project
  originSessionId: sess_cc7b19eb-deb6-4e4a-82db-5de5dd509ecb
---

**Audit remediation COMMITTED AND PUSHED 2026-09-09** — user committed `e8467d4` (zen revert) + `db15a2a` (all audit remediation: recheck fix, jan/orcarouter/wifi-psk cruft gone, docs corrected, openssh/nas/isPhysical/thermald consolidated, yoga-s2h extracted to hosts/yoga/yoga-s2h.nix). Yoga still NOT switched onto it.

**Pre-rebuild QC (final gate) — caught one regression, mine:** the sed line-range for the s2h extraction clipped `pkgs.vulkan-tools` out of yoga's systemPackages; flake check + dry-build + seam eyeballing all missed it, but `nix store diff-closures /run/current-system <new-toplevel>` exposed it. **Fix (restore vulkan-tools) is STAGED but uncommitted — user must commit+push before rebuilding.** After the fix the closure diff is exactly: `linux`→`linux-zen` (both 7.2.3, the intended revert) + `manifest.json` removed (upstream nixpkgs change riding the Sep-7 lock 93108a5 — old running generation predates it; harmless, not ours).

**QC techniques that worked (use again):**
- `nix store diff-closures` between `/run/current-system` and the built toplevel is the strongest pre-rebuild gate — catches package loss invisible to eval checks.
- Home-files preservation scan: walk the `home-files` store tree comparing against `/home/dk/<rel>` — but HM trees are ALL SYMLINKS, so `find -type f` silently returns 0 files and a vacuous "no diffs"; use `-type l -o -type f`. Result: exactly one diff = `.config/fish/config.fish` (intended ORCAROUTER removal); opencode.json byte-identical to deployed.

**Recheck fix behaviorally verified by A/B test (2026-09-09, pre-switch):** planted a `reboot` decision file with lid open; the NEW built script logs `post-abort recheck: lid is open, staying awake (reboot dropped)` and exits 0; the OLD script (still deployed at `/run/current-system/etc/systemd/system-sleep/yoga-s2h`) silently exits 0 — bug reproduced. See [[yoga-hibernate-status]] and [[zcode-shell-sandbox-etc]] for the sandbox workarounds the test needed.

**Still open:** latitude.yaml + nix-media.yaml encrypted to a STALE admin key (`age1vzw0xw2d6…`, not current `admin_david` `age1ff0ly0…`) — can't be decrypted/edited from yoga; their dead wifi PSK keys remain in place. Grafana `secret_key` stays plaintext — explicit user choice (Tailscale-only). Deferred: cache.lix.systems substituter removal, `nus` fish function on latitude/nix-media, `custom.mikrotikMcp` keep-or-kill (kept for now). wifi_home_psk plaintext value transited a session transcript during the sops decrypt — user advised rotation if it matters.

**Next step (user):** commit the staged vulkan-tools fix, push, then `./scripts/update-safe yoga test|switch`. Old s2h hook stays live until switch.
